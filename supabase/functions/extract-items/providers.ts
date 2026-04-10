export type RawItem = {
  name: string
  quantity: number | null
  unit: string | null
}

export interface VoiceProvider {
  extractItems(audioBase64: string): Promise<RawItem[]>
  extractItemsFromImage(imageBase64: string, mimeType: string): Promise<RawItem[]>
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

// ---------------------------------------------------------------------------
// OpenAI — Whisper (transcription) + GPT (extraction)
// ---------------------------------------------------------------------------

export type OpenAIConfig = {
  apiKey: string
  transcriptionModel: string
  extractionModel: string
}

export class OpenAIProvider implements VoiceProvider {
  constructor(private readonly cfg: OpenAIConfig) {}

  async extractItems(audioBase64: string): Promise<RawItem[]> {
    const transcript = await this._transcribe(audioBase64)
    if (!transcript.trim()) return []
    return this._extract(transcript)
  }

  async extractItemsFromImage(_imageBase64: string, _mimeType: string): Promise<RawItem[]> {
    throw new Error('unsupported_provider')
  }

  private async _transcribe(audioBase64: string): Promise<string> {
    const bytes = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0))
    const form = new FormData()
    form.append('file', new Blob([bytes], { type: 'audio/m4a' }), 'audio.m4a')
    form.append('model', this.cfg.transcriptionModel)

    const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.cfg.apiKey}` },
      body: form,
    })
    if (!res.ok) throw new Error('transcription_failed')
    const { text } = await res.json()
    return text ?? ''
  }

  private async _extract(transcript: string): Promise<RawItem[]> {
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: this.cfg.extractionModel,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: _extractionPrompt },
          { role: 'user', content: transcript },
        ],
      }),
    })
    if (!res.ok) throw new Error('extraction_failed')
    const data = await res.json()
    return _parseItems(data.choices?.[0]?.message?.content ?? '')
  }
}

// ---------------------------------------------------------------------------
// Google — Gemini multimodal (audio + extraction in a single call)
// ---------------------------------------------------------------------------

export type GoogleConfig = {
  apiKey: string
  model: string
}

export class GoogleProvider implements VoiceProvider {
  constructor(private readonly cfg: GoogleConfig) {}

  async extractItems(audioBase64: string): Promise<RawItem[]> {
    return this._extractWithInlineData(audioBase64, 'audio/mp4', _extractionPrompt)
  }

  async extractItemsFromImage(imageBase64: string, mimeType: string): Promise<RawItem[]> {
    return this._extractWithInlineData(imageBase64, mimeType, _imageExtractionPrompt)
  }

  private async _extractWithInlineData(
    dataBase64: string,
    mimeType: string,
    prompt: string,
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
      throw new Error('extraction_failed')
    }

    const data = await res.json()
    console.log('Google API response', JSON.stringify(data).slice(0, 500))
    const content: string = data.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
    return _parseItems(content)
  }
}

// ---------------------------------------------------------------------------
// Anthropic — requires a separate STT provider; Claude handles extraction only
// ---------------------------------------------------------------------------

// export type AnthropicConfig = {
//   apiKey: string
//   transcriptionProvider: VoiceProvider  // delegate STT elsewhere
//   extractionModel: string               // e.g. 'claude-haiku-4-5-20251001'
// }

// export class AnthropicProvider implements VoiceProvider {
//   constructor(private readonly cfg: AnthropicConfig) {}
//   async extractItems(audioBase64: string): Promise<RawItem[]> { ... }
// }
