import { GoogleProvider, OpenRouterProvider, VoiceProvider } from './providers.ts'
import { googleModel, qwenModel, xiaomiModel } from './models.ts'

export type ProviderName = 'google' | 'openrouter'

const googleProvider: VoiceProvider = new GoogleProvider({
  apiKey: Deno.env.get('GOOGLE_API_KEY')!,
  model: Deno.env.get('GOOGLE_MODEL') ?? googleModel,
})

const qwenProvider: VoiceProvider = new OpenRouterProvider({
  apiKey: Deno.env.get('OPENROUTER_API_KEY')!,
  model: qwenModel,
})

const xiaomiProvider: VoiceProvider = new OpenRouterProvider({
  apiKey: Deno.env.get('OPENROUTER_API_KEY')!,
  model: xiaomiModel,
})

export function getProvider(providerName?: string, model?: string): VoiceProvider {
  switch (providerName) {
    case 'openrouter':
      return model == xiaomiModel ? xiaomiProvider : qwenProvider
    case 'qwen':
      return qwenProvider
    case 'xiaomi':
      return xiaomiProvider
    case 'google':
    default:
      return googleProvider
  }
}
