import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apiKey, content-type',
}

serve(async (req) => {
    // Web entegrasyonu için CORS preflight kontrolü
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { strava_id, profile_url } = await req.json()

        if (!strava_id || !profile_url) {
            return new Response(
                JSON.stringify({ error: 'strava_id ve profile_url alanları zorunludur.' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
            )
        }

        // Storage ve DB güncellemesi için admin yetkili client oluşturuyoruz
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 1. Resmi Strava CDN üzerinden indir
        const response = await fetch(profile_url)
        if (!response.ok) {
            throw new Error('Profil resmi Strava CDN üzerinden indirilemedi.')
        }
        const blob = await response.blob()

        // 2. Resmi Supabase Storage içerisine 'avatars/{strava_id}.jpg' olarak yükle
        const fileName = `${strava_id}.jpg`
        const { error: storageError } = await supabaseAdmin.storage
            .from('avatars')
            .upload(fileName, blob, {
                contentType: 'image/jpeg',
                upsert: true // Kullanıcı resmini güncellerse üzerine yazması için
            })

        if (storageError) throw storageError

        // 3. Yüklenen resmin Public URL değerini al
        const { data: { publicUrl } } = supabaseAdmin.storage
            .from('avatars')
            .getPublicUrl(fileName)

        // 4. users tablosundaki avatar_url alanını güncelle
        const { error: dbError } = await supabaseAdmin
            .from('users')
            .update({ avatar_url: publicUrl })
            .eq('strava_id', strava_id)

        if (dbError) throw dbError

        return new Response(
            JSON.stringify({ success: true, avatar_url: publicUrl }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )

    } catch (error: any) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
        )
    }
})