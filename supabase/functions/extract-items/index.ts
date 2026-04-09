import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { provider } from './config.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const MAX_BYTES = 10 * 1024 * 1024

serve(async (req: Request) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return reply({ error: 'unauthorized' }, 401)

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user) return reply({ error: 'unauthorized' }, 401)

  const { audio: audioBase64 } = await req.json()
  if (!audioBase64) return reply({ error: 'empty_audio' }, 400)
  if (audioBase64.length > MAX_BYTES) return reply({ error: 'payload_too_large' }, 413)

  try {
    const items = await provider.extractItems(audioBase64)
    return reply({ items })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'unknown_error'
    return reply({ error: message }, 502)
  }
})

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
