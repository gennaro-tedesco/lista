import {
  GoogleProvider,
  GroqProvider,
  MistralProvider,
  VoiceProvider,
} from './providers.ts'
import {
  googleModel,
  groqExtractionModel,
  groqTranscriptionModel,
  groqVisionModel,
  mistralExtractionModel,
  mistralTranscriptionModel,
} from './models.ts'

export type ProviderName = 'google' | 'mistral' | 'groq'

const googleProvider: VoiceProvider = new GoogleProvider({
  apiKey: Deno.env.get('GOOGLE_API_KEY')!,
  model: Deno.env.get('GOOGLE_MODEL') ?? googleModel,
})

const mistralProvider: VoiceProvider = new MistralProvider({
  apiKey: Deno.env.get('MISTRAL_API_KEY')!,
  transcriptionModel: Deno.env.get('MISTRAL_TRANSCRIPTION_MODEL') ?? mistralTranscriptionModel,
  extractionModel: Deno.env.get('MISTRAL_EXTRACTION_MODEL') ?? mistralExtractionModel,
})

const groqProvider: VoiceProvider = new GroqProvider({
  apiKey: Deno.env.get('GROQ_API_KEY')!,
  transcriptionModel: Deno.env.get('GROQ_TRANSCRIPTION_MODEL') ?? groqTranscriptionModel,
  extractionModel: Deno.env.get('GROQ_EXTRACTION_MODEL') ?? groqExtractionModel,
  visionModel: Deno.env.get('GROQ_VISION_MODEL') ?? groqVisionModel,
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
