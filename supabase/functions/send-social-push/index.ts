// Supabase Edge Function: fan-out social push via FCM + APNs (+ Live Activity).
// Secrets (set whichever delivery path you use):
//
// FCM (preferred for Flutter firebase_messaging tokens, kind=fcm):
//   FIREBASE_SERVICE_ACCOUNT_JSON  — full service account JSON (one line OK)
//   FIREBASE_PROJECT_ID            — optional; defaults to JSON project_id
//
// Direct APNs (kind=apns / live_activity):
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID
//   APNS_PRIVATE_KEY  (PKCS8 .p8 contents, newlines as \n)
//   APNS_ENVIRONMENT  = sandbox | production
//
// Deploy: supabase functions deploy send-social-push
// Hook: Database Webhook on push_dispatch_queue INSERT → this function
//   OR cron every minute invoking with { "drain": true }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'
import { SignJWT, importPKCS8 } from 'https://deno.land/x/jose@v5.9.6/index.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

type QueueRow = {
  id: string
  recipient_id: string
  title: string
  body: string
  data: Record<string, unknown>
}

type TokenRow = {
  token: string
  kind: string
  environment: string
  bundle_id: string | null
}

type ServiceAccount = {
  project_id?: string
  client_email: string
  private_key: string
}

let cachedFcmToken: string | null = null
let cachedFcmTokenExp = 0

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const payload = await req.json().catch(() => ({}))
    let rows: QueueRow[] = []

    if (payload?.record && payload.record.recipient_id) {
      rows = [payload.record as QueueRow]
    } else if (payload?.drain) {
      const { data, error } = await supabase
        .from('push_dispatch_queue')
        .select('id, recipient_id, title, body, data')
        .is('dispatched_at', null)
        .order('created_at', { ascending: true })
        .limit(40)
      if (error) throw error
      rows = (data ?? []) as QueueRow[]
    } else if (payload?.recipient_id && payload?.title) {
      rows = [
        {
          id: payload.id ?? crypto.randomUUID(),
          recipient_id: payload.recipient_id,
          title: payload.title,
          body: payload.body ?? '',
          data: payload.data ?? {},
        },
      ]
    }

    if (rows.length === 0) {
      return json({ ok: true, sent: 0 })
    }

    const keyId = Deno.env.get('APNS_KEY_ID')
    const teamId = Deno.env.get('APNS_TEAM_ID')
    const bundleId = Deno.env.get('APNS_BUNDLE_ID') ?? 'com.intime.inTimeBartender'
    const privateKeyPem = (Deno.env.get('APNS_PRIVATE_KEY') ?? '').replace(
      /\\n/g,
      '\n',
    )
    const defaultEnv = Deno.env.get('APNS_ENVIRONMENT') ?? 'sandbox'
    const hasApns = Boolean(keyId && teamId && privateKeyPem)
    const hasFcm = Boolean(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON'))

    if (!hasApns && !hasFcm) {
      return json(
        {
          ok: false,
          error:
            'Push secrets missing. Set FIREBASE_SERVICE_ACCOUNT_JSON and/or APNS_KEY_ID + APNS_TEAM_ID + APNS_PRIVATE_KEY.',
          queued: rows.length,
        },
        503,
      )
    }

    let apnsJwt: string | null = null
    if (hasApns) {
      const privateKey = await importPKCS8(privateKeyPem, 'ES256')
      apnsJwt = await new SignJWT({})
        .setProtectedHeader({ alg: 'ES256', kid: keyId! })
        .setIssuer(teamId!)
        .setIssuedAt()
        .sign(privateKey)
    }

    let sent = 0
    for (const row of rows) {
      const { data: tokens, error } = await supabase
        .from('device_push_tokens')
        .select('token, kind, environment, bundle_id')
        .eq('user_id', row.recipient_id)

      if (error) {
        console.error('token lookup', error)
        continue
      }

      const list = (tokens ?? []) as TokenRow[]
      for (const t of list) {
        const topic = t.bundle_id || bundleId
        const host =
          (t.environment || defaultEnv) === 'production'
            ? 'api.push.apple.com'
            : 'api.sandbox.push.apple.com'

        if (t.kind === 'fcm' && hasFcm) {
          const ok = await sendFcm({
            token: t.token,
            title: row.title,
            body: row.body,
            data: row.data,
          })
          if (ok) sent += 1
        } else if (t.kind === 'apns' && apnsJwt) {
          const ok = await sendApns({
            host,
            token: t.token,
            jwt: apnsJwt,
            topic,
            payload: {
              aps: {
                alert: { title: row.title, body: row.body },
                sound: 'default',
                'mutable-content': 1,
              },
              ...row.data,
            },
            pushType: 'alert',
          })
          if (ok) sent += 1
        } else if (t.kind === 'live_activity' && apnsJwt) {
          const sender =
            (row.data?.sender_name as string | undefined) ?? 'Friend'
          const ok = await sendApns({
            host,
            token: t.token,
            jwt: apnsJwt,
            topic: `${topic}.push-type.liveactivity`,
            payload: {
              aps: {
                timestamp: Math.floor(Date.now() / 1000),
                event: 'update',
                'content-state': {},
                alert: {
                  title: row.title,
                  body: row.body,
                  sound: 'default',
                },
              },
              socialAlertTitle: row.title,
              socialAlertBody: row.body,
              socialAlertSender: sender,
              hasSocialAlert: true,
              status: row.title.toUpperCase().slice(0, 28),
            },
            pushType: 'liveactivity',
          })
          if (ok) sent += 1
        }
      }

      if (row.id) {
        await supabase
          .from('push_dispatch_queue')
          .update({ dispatched_at: new Date().toISOString() })
          .eq('id', row.id)
      }
    }

    return json({ ok: true, sent, processed: rows.length })
  } catch (e) {
    console.error(e)
    return json({ ok: false, error: String(e) }, 500)
  }
})

async function loadServiceAccount(): Promise<ServiceAccount> {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? ''
  return JSON.parse(raw) as ServiceAccount
}

async function getFirebaseAccessToken(): Promise<{
  accessToken: string
  projectId: string
}> {
  const now = Math.floor(Date.now() / 1000)
  const sa = await loadServiceAccount()
  const projectId =
    Deno.env.get('FIREBASE_PROJECT_ID') || sa.project_id || ''
  if (!projectId) {
    throw new Error('FIREBASE_PROJECT_ID missing')
  }
  if (cachedFcmToken && cachedFcmTokenExp > now + 60) {
    return { accessToken: cachedFcmToken, projectId }
  }

  const privateKey = await importPKCS8(
    sa.private_key.replace(/\\n/g, '\n'),
    'RS256',
  )
  const jwt = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey)

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const jsonBody = await res.json()
  if (!res.ok || !jsonBody.access_token) {
    throw new Error(`Firebase auth failed: ${JSON.stringify(jsonBody)}`)
  }
  cachedFcmToken = jsonBody.access_token as string
  cachedFcmTokenExp = now + Number(jsonBody.expires_in || 3600)
  return { accessToken: cachedFcmToken, projectId }
}

async function sendFcm(opts: {
  token: string
  title: string
  body: string
  data: Record<string, unknown>
}): Promise<boolean> {
  try {
    const { accessToken, projectId } = await getFirebaseAccessToken()
    const stringData: Record<string, string> = {}
    for (const [k, v] of Object.entries(opts.data || {})) {
      if (v == null) continue
      stringData[k] = typeof v === 'string' ? v : JSON.stringify(v)
    }
    stringData.title = opts.title
    stringData.body = opts.body

    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: opts.token,
            notification: { title: opts.title, body: opts.body },
            data: stringData,
            apns: {
              headers: {
                'apns-priority': '10',
                'apns-push-type': 'alert',
              },
              payload: {
                aps: {
                  alert: { title: opts.title, body: opts.body },
                  sound: 'default',
                  'mutable-content': 1,
                },
              },
            },
            android: {
              priority: 'HIGH',
              notification: {
                channel_id: 'blind_tiger_social',
                sound: 'default',
              },
            },
          },
        }),
      },
    )
    if (!res.ok) {
      console.error('FCM error', res.status, await res.text())
      return false
    }
    return true
  } catch (e) {
    console.error('FCM send failed', e)
    return false
  }
}

async function sendApns(opts: {
  host: string
  token: string
  jwt: string
  topic: string
  payload: Record<string, unknown>
  pushType: 'alert' | 'liveactivity'
}): Promise<boolean> {
  const url = `https://${opts.host}/3/device/${opts.token}`
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      authorization: `bearer ${opts.jwt}`,
      'apns-topic': opts.topic,
      'apns-push-type': opts.pushType,
      'apns-priority': '10',
      'content-type': 'application/json',
    },
    body: JSON.stringify(opts.payload),
  })
  if (!res.ok) {
    const text = await res.text()
    console.error('APNs error', res.status, text)
    return false
  }
  return true
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
