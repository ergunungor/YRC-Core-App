import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apiKey, content-type',
}

serve(async (req) => {
  // Web entegrasyonu için CORS ön kontrolü
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { code } = await req.json()

    if (!code) {
      throw new Error('Strava Auth Code eksik.')
    }

    // Flutter tarafındaki gizli anahtarımızı backend'e taşıdık
    const clientId = '262903'
    const clientSecret = 'b965b158fc3d49d12cb2073c79662a1b1ce5389c'

    // Strava'ya token isteğini backend sunucumuz atıyor (CORS yok)
    const response = await fetch('https://www.strava.com/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: clientId,
        client_secret: clientSecret,
        code: code,
        grant_type: 'authorization_code'
      })
    })

    const data = await response.json()

    if (!response.ok) {
      throw new Error(data.message || 'Token alınamadı')
    }

    // Tokenları ve atlet verisini Flutter'a güvenle geri dönüyoruz
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})