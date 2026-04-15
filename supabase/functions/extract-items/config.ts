import {
  GoogleProvider,
  GroqProvider,
  MistralProvider,
  VoiceProvider,
} from './providers.ts'

export type ProviderName = 'google' | 'mistral' | 'groq'

const googleProvider: VoiceProvider = new GoogleProvider({
  apiKey: Deno.env.get('GOOGLE_API_KEY')!,
  model: Deno.env.get('GOOGLE_MODEL') ?? 'gemini-3.1-flash-lite-preview',
})

const mistralProvider: VoiceProvider = new MistralProvider({
  apiKey: Deno.env.get('MISTRAL_API_KEY')!,
  transcriptionModel:
    Deno.env.get('MISTRAL_TRANSCRIPTION_MODEL') ??
    'voxtral-mini-2507',
  extractionModel:
    Deno.env.get('MISTRAL_EXTRACTION_MODEL') ?? 'mistral-large-latest',
})

const groqProvider: VoiceProvider = new GroqProvider({
  apiKey: Deno.env.get('GROQ_API_KEY')!,
  transcriptionModel: Deno.env.get('GROQ_TRANSCRIPTION_MODEL') ?? 'whisper-large-v3',
  extractionModel: Deno.env.get('GROQ_EXTRACTION_MODEL') ?? 'llama-3.3-70b-versatile',
  visionModel: Deno.env.get('GROQ_VISION_MODEL') ?? 'meta-llama/llama-4-scout-17b-16e-instruct',
})

export function getProvider(providerName?: string): VoiceProvider {
  switch (providerName) {
    case 'mistral':
      return mistralProvider
    case 'groq':
      return groqProvider
    case 'google':
    default:
      return googleProvider
  }
}
