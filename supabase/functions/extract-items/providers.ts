export type RawItem = {
  name: string
  quantity: number | null
  unit: string | null
}

export interface VoiceProvider {
  extractItems(audioBase64: string): Promise<RawItem[]>
  extractItemsFromImage(imageBase64: string, mimeType: string): Promise<RawItem[]>
}

const _itemsResponseSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          name: { type: 'string' },
          quantity: { type: ['number', 'null'] },
          unit: { type: ['string', 'null'] },
        },
        required: ['name', 'quantity', 'unit'],
      },
    },
  },
  required: ['items'],
} as const

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

function _groqErrorCode(status: number, body: string): string {
  const normalized = body.toLowerCase()
  if (status == 503 || normalized.includes('service unavailable')) {
    return 'provider_unavailable'
  }
  if (status == 404 || normalized.includes('model not found') || normalized.includes('does not exist')) {
    return 'model_not_found'
  }
  if (status == 429 || normalized.includes('rate limit') || normalized.includes('quota')) {
    return 'quota_exceeded'
  }
  return 'extraction_failed'
}

function _mistralErrorCode(status: number, body: string): string {
  const normalized = body.toLowerCase()
  if (status == 503 || normalized.includes('unavailable')) {
    return 'provider_unavailable'
  }
  if (status == 404 || normalized.includes('not found') || normalized.includes('unknown model')) {
    return 'model_not_found'
  }
  if (
    status == 429 ||
    normalized.includes('resource_exhausted') ||
    normalized.includes('quota') ||
    normalized.includes('billing') ||
    normalized.includes('credit')
  ) {
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

function _messageContentToString(content: unknown): string {
  if (typeof content == 'string') return content
  if (content && typeof content == 'object') return JSON.stringify(content)
  return ''
}

function _responseFormatJsonSchema() {
  return {
    type: 'json_schema',
    json_schema: {
      name: 'shopping_items',
      strict: true,
      schema: _itemsResponseSchema,
    },
  }
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

export type MistralConfig = {
  apiKey: string
  transcriptionModel: string
  extractionModel: string
}

export class MistralProvider implements VoiceProvider {
  constructor(private readonly cfg: MistralConfig) {}

  async extractItems(audioBase64: string): Promise<RawItem[]> {
    const transcript = await this._transcribe(audioBase64)
    if (!transcript.trim()) {
      throw new Error('empty_model_output')
    }
    return this._extractFromText(transcript)
  }

  async extractItemsFromImage(imageBase64: string, mimeType: string): Promise<RawItem[]> {
    const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        model: this.cfg.extractionModel,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: _imageExtractionPrompt },
              {
                type: 'image_url',
                image_url: { url: `data:${mimeType};base64,${imageBase64}` },
              },
            ],
          },
        ],
        response_format: _responseFormatJsonSchema(),
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Mistral API error', res.status, errBody)
      throw new Error(_mistralErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const content = _messageContentToString(data.choices?.[0]?.message?.content)
    if (!content.trim()) throw new Error('empty_model_output')
    return _parseItems(content)
  }

  private async _transcribe(audioBase64: string): Promise<string> {
    const bytes = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0))
    const form = new FormData()
    form.append('file', new Blob([bytes], { type: 'audio/mp4' }), 'audio.m4a')
    form.append('model', this.cfg.transcriptionModel)

    const res = await fetch('https://api.mistral.ai/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        Accept: 'application/json',
      },
      body: form,
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Mistral API error', res.status, errBody)
      throw new Error(_mistralErrorCode(res.status, errBody))
    }

    const data = await res.json()
    return data.text ?? ''
  }

  private async _extractFromText(transcript: string): Promise<RawItem[]> {
    const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        model: this.cfg.extractionModel,
        messages: [
          { role: 'system', content: _extractionPrompt },
          { role: 'user', content: transcript },
        ],
        response_format: _responseFormatJsonSchema(),
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Mistral API error', res.status, errBody)
      throw new Error(_mistralErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const content = _messageContentToString(data.choices?.[0]?.message?.content)
    if (!content.trim()) {
      throw new Error('empty_model_output')
    }
    try {
      return _parseItems(content)
    } catch {
      throw new Error('invalid_model_output')
    }
  }
}

export type GroqConfig = {
  apiKey: string
  transcriptionModel: string
  extractionModel: string
  visionModel: string
}

export class GroqProvider implements VoiceProvider {
  constructor(private readonly cfg: GroqConfig) {}

  async extractItems(audioBase64: string): Promise<RawItem[]> {
    const transcript = await this._transcribe(audioBase64)
    if (!transcript.trim()) {
      throw new Error('empty_model_output')
    }
    return this._extractFromText(transcript)
  }

  async extractItemsFromImage(imageBase64: string, mimeType: string): Promise<RawItem[]> {
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: this.cfg.visionModel,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: _imageExtractionPrompt },
              {
                type: 'image_url',
                image_url: { url: `data:${mimeType};base64,${imageBase64}` },
              },
            ],
          },
        ],
        response_format: { type: 'json_object' },
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Groq API error', res.status, errBody)
      throw new Error(_groqErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const content = _messageContentToString(data.choices?.[0]?.message?.content)
    if (!content.trim()) throw new Error('empty_model_output')
    return _parseItems(content)
  }

  private async _transcribe(audioBase64: string): Promise<string> {
    const bytes = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0))
    const form = new FormData()
    form.append('file', new Blob([bytes], { type: 'audio/mp4' }), 'audio.m4a')
    form.append('model', this.cfg.transcriptionModel)

    const res = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
      },
      body: form,
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Groq API error', res.status, errBody)
      throw new Error(_groqErrorCode(res.status, errBody))
    }

    const data = await res.json()
    return data.text ?? ''
  }

  private async _extractFromText(transcript: string): Promise<RawItem[]> {
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: this.cfg.extractionModel,
        messages: [
          { role: 'system', content: _extractionPrompt },
          { role: 'user', content: transcript },
        ],
        response_format: { type: 'json_object' },
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Groq API error', res.status, errBody)
      throw new Error(_groqErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const content = _messageContentToString(data.choices?.[0]?.message?.content)
    if (!content.trim()) {
      throw new Error('empty_model_output')
    }
    try {
      return _parseItems(content)
    } catch {
      throw new Error('invalid_model_output')
    }
  }
}
