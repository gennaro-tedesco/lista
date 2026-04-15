import { GoogleProvider, VoiceProvider } from './providers.ts'

export const provider: VoiceProvider = new GoogleProvider({
  apiKey: Deno.env.get('GOOGLE_API_KEY')!,
  model: 'gemini-3.1-flash-lite-preview',
})
