export type RawItem = {
  name: string
  quantity: number | null
  unit: string | null
}

export interface VoiceProvider {
  extractItems(audioBase64: string): Promise<RawItem[]>
  extractItemsFromImage(imageBase64: string, mimeType: string): Promise<RawItem[]>
}

function _googleErrorCode(status: number, body: string): string {
  if (status == 503 && body.includes('"status": "UNAVAILABLE"')) {
    return 'provider_unavailable'
  }
  if (status == 404 || body.includes('not found') || body.includes('not supported')) {
    return 'model_not_found'
  }
  if (status == 429 || body.includes('RESOURCE_EXHAUSTED') || body.includes('quota')) {
    return 'quota_exceeded'
  }
  return 'extraction_failed'
}

function _openRouterErrorCode(status: number, body: string): string {
  const normalized = body.toLowerCase()
  if (status == 502 || status == 503 || normalized.includes('unavailable')) {
    return 'provider_unavailable'
  }
  if (status == 404 || normalized.includes('model not found') || normalized.includes('no endpoints')) {
    return 'model_not_found'
  }
  if (status == 402 || status == 429 || normalized.includes('quota')) {
    return 'quota_exceeded'
  }
  return 'extraction_failed'
}

const _extractionPrompt = [
  'Extract shopping items from the transcript.',
  'Return JSON: {"items": [{"name": string, "quantity": number | null, "unit": string | null}]}',
  'Rules:',
  '- name: lowercase singular noun',
  '- quantity: number (integer or decimal), null if unspecified',
  '- unit: normalised (g, kg, l, ml, bottles, pieces, etc.), null if unspecified',
  '- split compound mentions into individual items',
].join('\n')

const _imageExtractionPrompt = [
  'Extract shopping items visible in the image.',
  'Return JSON: {"items": [{"name": string, "quantity": number | null, "unit": string | null}]}',
  'Rules:',
  '- name: lowercase singular noun',
  '- quantity: number (integer or decimal), null if unspecified',
  '- unit: normalised (g, kg, l, ml, bottles, pieces, etc.), null if unspecified',
  '- ignore prices, totals, store names, and non-shopping text',
].join('\n')

function _parseItems(content: string): RawItem[] {
  let parsed: { items?: unknown[] }
  try {
    parsed = JSON.parse(content)
  } catch {
    throw new Error('invalid_json')
  }
  if (!Array.isArray(parsed?.items)) throw new Error('schema_mismatch')
  return (parsed.items as unknown[]).filter(
    (item): item is RawItem =>
      typeof (item as Record<string, unknown>)?.name === 'string' &&
      (item as Record<string, unknown>).name !== '',
  )
}

export type GoogleConfig = {
  apiKey: string
  model: string
}

export class GoogleProvider implements VoiceProvider {
  constructor(private readonly cfg: GoogleConfig) {}

  async extractItems(audioBase64: string): Promise<RawItem[]> {
    return this._extractWithInlineData(
      audioBase64,
      'audio/mp4',
      _extractionPrompt,
      'empty_model_output',
    )
  }

  async extractItemsFromImage(imageBase64: string, mimeType: string): Promise<RawItem[]> {
    return this._extractWithInlineData(
      imageBase64,
      mimeType,
      _imageExtractionPrompt,
      'invalid_json',
    )
  }

  private async _extractWithInlineData(
    dataBase64: string,
    mimeType: string,
    prompt: string,
    emptyResultCode: string,
  ): Promise<RawItem[]> {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.cfg.model}:generateContent?key=${this.cfg.apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  inline_data: {
                    mime_type: mimeType,
                    data: dataBase64,
                  },
                },
                { text: prompt },
              ],
            },
          ],
          generationConfig: {
            response_mime_type: 'application/json',
          },
        }),
      },
    )

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Google API error', res.status, errBody)
      throw new Error(_googleErrorCode(res.status, errBody))
    }

    const data = await res.json()
    console.log('Google API response', JSON.stringify(data).slice(0, 500))
    const content: string = data.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
    if (!content.trim()) {
      throw new Error(emptyResultCode)
    }
    try {
      return _parseItems(content)
    } catch (err) {
      if (emptyResultCode == 'empty_model_output') {
        throw new Error('invalid_model_output')
      }
      throw err
    }
  }
}

export type OpenRouterConfig = {
  apiKey: string
  model: string
}

export class OpenRouterProvider implements VoiceProvider {
  constructor(private readonly cfg: OpenRouterConfig) {}

  async extractItems(audioBase64: string): Promise<RawItem[]> {
    return this._extract(
      _extractionPrompt.replace('the transcript', 'the audio recording'),
      { type: 'input_audio', input_audio: { data: audioBase64, format: 'm4a' } },
    )
  }

  async extractItemsFromImage(imageBase64: string, mimeType: string): Promise<RawItem[]> {
    return this._extract(_imageExtractionPrompt, {
      type: 'image_url',
      image_url: { url: `data:${mimeType};base64,${imageBase64}` },
    })
  }

  private async _extract(prompt: string, input: Record<string, unknown>): Promise<RawItem[]> {
    const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/gennaro-tedesco/lista',
        'X-OpenRouter-Title': 'Lista item extraction',
      },
      body: JSON.stringify({
        model: this.cfg.model,
        messages: [{ role: 'user', content: [{ type: 'text', text: prompt }, input] }],
        response_format: { type: 'json_object' },
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('OpenRouter API error', res.status, errBody)
      throw new Error(_openRouterErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const content: string = data.choices?.[0]?.message?.content ?? ''
    if (!content.trim()) throw new Error('empty_model_output')
    return _parseItems(content)
  }
}
