import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { encode as base64UrlEncode } from "https://deno.land/std@0.168.0/encoding/base64url.ts"

const VAPID_PUBLIC_KEY = "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8"
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY') || "hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8"

interface PushSubscription {
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
}

interface NotificationPayload {
  notification_id?: string;
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  type?: string;
  data?: any;
}

// Convert VAPID private key from base64url to Uint8Array
function base64UrlToUint8Array(base64url: string): Uint8Array {
  const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
  const padding = '='.repeat((4 - base64.length % 4) % 4);
  const base64Padded = base64 + padding;
  const binary = atob(base64Padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// Generate VAPID JWT token
async function generateVAPIDToken(audience: string): Promise<string> {
  const header = { typ: "JWT", alg: "ES256" };
  const exp = Math.floor(Date.now() / 1000) + 12 * 60 * 60; // 12 hours
  const payload = {
    aud: audience,
    exp: exp,
    sub: "mailto:admin@aqura.app"
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // Import private key using JWK format
  // The public key is "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8"
  // It's 65 bytes: 0x04 (uncompressed point indicator) + 32 bytes X + 32 bytes Y
  // We need to extract X and Y coordinates
  const publicKeyBytes = base64UrlToUint8Array(VAPID_PUBLIC_KEY);
  const x = base64UrlEncode(publicKeyBytes.slice(1, 33)); // Skip 0x04 prefix, take next 32 bytes
  const y = base64UrlEncode(publicKeyBytes.slice(33, 65)); // Take last 32 bytes
  
  const jwk = {
    kty: "EC",
    crv: "P-256",
    x: x,
    y: y,
    d: VAPID_PRIVATE_KEY, // Already in base64url format
    ext: true
  };
  
  const cryptoKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    {
      name: "ECDSA",
      namedCurve: "P-256"
    },
    false,
    ["sign"]
  );

  // Sign the token
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    {
      name: "ECDSA",
      hash: { name: "SHA-256" }
    },
    cryptoKey,
    encoder.encode(unsignedToken)
  );

  const encodedSignature = base64UrlEncode(signature);
  return `${unsignedToken}.${encodedSignature}`;
}

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const { subscription, payload }: { 
      subscription: PushSubscription; 
      payload: NotificationPayload;
    } = await req.json()

    // Validate input
    if (!subscription || !payload) {
      return new Response(
        JSON.stringify({ error: 'Missing subscription or payload' }),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('📤 Sending push notification to:', subscription.endpoint);

    // Extract audience (origin) from endpoint
    const endpointUrl = new URL(subscription.endpoint);
    const audience = `${endpointUrl.protocol}//${endpointUrl.host}`;

    // Generate VAPID JWT token
    const vapidToken = await generateVAPIDToken(audience);

    // Extract notification_id from payload data
    const notificationId = payload.data?.notification_id || payload.data?.notificationId || payload.notification_id;
    const finalEndpoint = subscription.endpoint;
    
    // Send FULL payload to Service Worker so it can display immediately without fetching
    const triggerData = JSON.stringify({
      notification_id: notificationId,
      notificationId: notificationId, // Include both formats
      title: payload.title,
      body: payload.body,
      message: payload.body, // Include as 'message' too for compatibility
      icon: payload.icon || '/icons/icon-192x192.png',
      badge: payload.badge || '/icons/icon-96x96.png',
      type: payload.type || payload.data?.type,
      data: {
        notification_id: notificationId,
        notificationId: notificationId,
        type: payload.type || payload.data?.type,
        url: payload.data?.url || '/notifications'
      },
      timestamp: new Date().toISOString()
    });
    
    console.log('📦 Sending FULL notification data:', triggerData);
    
    const pushResponse = await fetch(finalEndpoint, {
      method: 'POST',
      headers: {
        'TTL': '86400', // 24 hours
        'Authorization': `vapid t=${vapidToken}, k=${VAPID_PUBLIC_KEY}`,
        'Content-Length': triggerData.length.toString(),
        'Urgency': 'high'
      },
      body: triggerData
    });

    if (!pushResponse.ok) {
      const errorText = await pushResponse.text();
      throw new Error(`Push service responded with ${pushResponse.status}: ${errorText}`);
    }

    console.log('✅ Push notification sent successfully with payload data');

    return new Response(
      JSON.stringify({ success: true, message: 'Notification sent' }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )

  } catch (error) {
    console.error('Push notification error:', error)
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ 
        error: 'Failed to send notification', 
        details: errorMessage 
      }),
      {
        status: 500,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )
  }
})