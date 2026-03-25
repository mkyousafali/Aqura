import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const GRAPH_API_VERSION = "v22.0";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Auth check
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();
    const { action, account_id, ...params } = body;

    if (!action) {
      return new Response(
        JSON.stringify({ error: "Missing action parameter" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get account credentials
    let accessToken = "";
    let phoneNumberId = "";
    let wabaId = "";

    if (account_id) {
      const { data: account } = await supabase
        .from("wa_accounts")
        .select("access_token, phone_number_id, waba_id")
        .eq("id", account_id)
        .single();

      if (!account) {
        return new Response(
          JSON.stringify({ error: "Account not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      accessToken = account.access_token;
      phoneNumberId = account.phone_number_id;
      wabaId = account.waba_id || "";
    } else {
      // Fallback to env vars
      accessToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN") || "";
      phoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") || "";
    }

    if (!accessToken || !phoneNumberId) {
      return new Response(
        JSON.stringify({ error: "WhatsApp credentials not available" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let result: any;

    switch (action) {
      // ─── Send Message ──────────────────────────────────
      case "send_message":
        result = await sendMessage(accessToken, phoneNumberId, params);
        break;

      // ─── Send Template Message ─────────────────────────
      case "send_template":
        result = await sendTemplate(accessToken, phoneNumberId, params);
        break;

      // ─── Mark Message as Read ──────────────────────────
      case "mark_read":
        result = await markAsRead(accessToken, phoneNumberId, params.message_id);
        break;

      // ─── Get Business Profile ──────────────────────────
      case "get_business_profile":
        result = await getBusinessProfile(accessToken, phoneNumberId);
        break;

      // ─── Update Business Profile ───────────────────────
      case "update_business_profile":
        result = await updateBusinessProfile(accessToken, phoneNumberId, params.profile);
        break;

      // ─── Create Template ───────────────────────────────
      case "create_template":
        result = await createTemplate(accessToken, wabaId, params.template, phoneNumberId);
        break;

      // ─── Get Templates ────────────────────────────────
      case "get_templates":
        result = await getTemplates(accessToken, wabaId, params.limit, params.after);
        break;

      // ─── Delete Template ───────────────────────────────
      case "delete_template":
        result = await deleteTemplate(accessToken, wabaId, params.template_name);
        break;

      // ─── Get Media URL ────────────────────────────────
      case "get_media":
        result = await getMediaUrl(accessToken, params.media_id);
        break;

      // ─── Upload Media ─────────────────────────────────
      case "upload_media":
        result = await uploadMedia(accessToken, phoneNumberId, params.file_url, params.mime_type);
        break;

      // ─── Get Phone Numbers ────────────────────────────
      case "get_phone_numbers":
        result = await getPhoneNumbers(accessToken, wabaId);
        break;

      // ─── Test Connection ──────────────────────────────
      case "test_connection":
        result = await testConnection(accessToken, phoneNumberId);
        break;

      // ─── Send Broadcast (fire-and-forget with auto-continue) ──────────────
      // Returns immediately, processes in background to avoid Kong 504 timeout.
      // If the function hits its 60s time limit, this .then() handler auto-invokes
      // a NEW request to continue sending remaining pending recipients.
      // IMPORTANT: Auto-continue happens ONLY here — NOT inside sendBroadcast() —
      // to prevent duplicate chains (which cause exponential worker spawning).
      // RELIABILITY: Uses fire-and-forget fetch() with 3 retries to survive
      // edge runtime kills, network blips, and container restarts over 40+ cycles.
      case "send_broadcast": {
        // Start broadcast in background — do NOT await
        sendBroadcast(supabase, accessToken, phoneNumberId, params).then(async (result) => {
          // If timed out, auto-continue by calling ourselves again (SINGLE chain only)
          if (result?.timedOut) {
            console.log(`[Broadcast] ↪ Auto-continue: ${result.sent} sent this round, invoking next batch...`);
            // Minimal delay (1s) to let DB writes settle
            await new Promise((r) => setTimeout(r, 1000));

            const continueBody = JSON.stringify({
              action: 'send_broadcast',
              account_id: params.account_id || account_id,
              broadcast_id: params.broadcast_id,
              template_name: params.template_name,
              language: params.language,
              components: params.components,
              cached_media_id: result.cached_media_id || params.cached_media_id,
            });

            const edgeFnUrl = Deno.env.get("SUPABASE_URL") + "/functions/v1/whatsapp-manage";
            const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

            // Retry up to 7 times with aggressive backoff
            for (let attempt = 1; attempt <= 7; attempt++) {
              try {
                console.log(`[Broadcast] ↪ Auto-continue attempt ${attempt}/7...`);
                const resp = await fetch(edgeFnUrl, {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${serviceKey}`,
                  },
                  body: continueBody,
                  signal: AbortSignal.timeout(50000), // 50s timeout (more aggressive)
                });
                if (resp.ok) {
                  console.log(`[Broadcast] ↪ Auto-continue invoked successfully (attempt ${attempt})`);
                  break; // success
                } else {
                  const errText = await resp.text().catch(() => "");
                  console.error(`[Broadcast] ❌ Auto-continue HTTP ${resp.status} (attempt ${attempt}): ${errText.substring(0, 200)}`);
                  // Retry on non-2xx
                  if (attempt < 7) {
                    const delayMs = attempt <= 3 ? 500 * attempt : Math.min(15000, 1000 * Math.pow(2, attempt));
                    await new Promise(r => setTimeout(r, delayMs));
                  }
                }
              } catch (fetchErr: any) {
                console.error(`[Broadcast] ❌ Auto-continue fetch error (attempt ${attempt}): ${fetchErr?.message}`);
                // Aggressive backoff on error
                if (attempt < 7) {
                  const delayMs = attempt <= 3 ? 500 * attempt : Math.min(15000, 1000 * Math.pow(2, attempt));
                  console.log(`[Broadcast] ↪ Retrying in ${delayMs / 1000}s...`);
                  await new Promise(r => setTimeout(r, delayMs));
                }
              }
            }
          }
        }).catch((err) => {
          console.error("[Broadcast] Background processing error:", err);
        });
        // Return immediately so the frontend doesn't timeout
        return new Response(
          JSON.stringify({ success: true, data: { status: "processing", message: "Broadcast started, processing in background" } }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // ─── Slow Ecosystem Retry (3 msg/s, only ecosystem-failed recipients) ──
      // Standalone action: reads ecosystem-failed recipients from DB, sends them
      // at a safe slow rate (~3/s) to avoid triggering ecosystem filter again.
      // Auto-continues itself if time limit hit.
      case "send_eco_retry": {
        sendEcoRetry(supabase, accessToken, phoneNumberId, params).then(async (result) => {
          if (result?.timedOut) {
            console.log(`[EcoRetry] ↪ Auto-continue: ${result.sent} sent this round, continuing...`);
            await new Promise((r) => setTimeout(r, 5000)); // 5s gap between rounds

            const continueBody = JSON.stringify({
              action: 'send_eco_retry',
              account_id: params.account_id || account_id,
              broadcast_id: params.broadcast_id,
              template_name: params.template_name,
              language: params.language,
              components: params.components,
              cached_media_id: result.cached_media_id || params.cached_media_id,
            });

            const edgeFnUrl = Deno.env.get("SUPABASE_URL") + "/functions/v1/whatsapp-manage";
            const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

            for (let attempt = 1; attempt <= 3; attempt++) {
              try {
                const resp = await fetch(edgeFnUrl, {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${serviceKey}`,
                  },
                  body: continueBody,
                  signal: AbortSignal.timeout(30000),
                });
                if (resp.ok) {
                  console.log(`[EcoRetry] ↪ Auto-continue invoked (attempt ${attempt})`);
                  break;
                } else {
                  console.error(`[EcoRetry] ❌ Auto-continue HTTP ${resp.status} (attempt ${attempt})`);
                  if (attempt < 3) await new Promise(r => setTimeout(r, 3000 * attempt));
                }
              } catch (e: any) {
                console.error(`[EcoRetry] ❌ Auto-continue error (attempt ${attempt}): ${e?.message}`);
                if (attempt < 3) await new Promise(r => setTimeout(r, 3000 * attempt));
              }
            }
          }
        }).catch((err) => {
          console.error("[EcoRetry] Background error:", err);
        });
        return new Response(
          JSON.stringify({ success: true, data: { status: "processing", message: "Ecosystem retry started, processing slowly in background" } }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      default:
        return new Response(
          JSON.stringify({ error: `Unknown action: ${action}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }

    return new Response(
      JSON.stringify({ success: true, data: result }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("whatsapp-manage error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// ─── Helper: Meta API Request ────────────────────────────────────
async function metaApi(
  accessToken: string,
  endpoint: string,
  method = "GET",
  body?: any
): Promise<any> {
  const url = `https://graph.facebook.com/${GRAPH_API_VERSION}/${endpoint}`;
  const options: RequestInit = {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  };
  if (body && method !== "GET") {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(url, options);
  const data = await response.json();

  if (!response.ok) {
    console.error("Meta API error response:", JSON.stringify(data, null, 2));
    const errMsg = data.error?.message || `Meta API error: ${response.status}`;
    const errCode = data.error?.code || '';
    const errSubcode = data.error?.error_subcode || '';
    const errDetail = data.error?.error_user_msg || data.error?.error_data?.details || '';
    throw new Error(`${errMsg}${errCode ? ` (code: ${errCode})` : ''}${errSubcode ? ` (subcode: ${errSubcode})` : ''}${errDetail ? ` - ${errDetail}` : ''}`);
  }
  return data;
}

// ─── Send Text/Media Message ─────────────────────────────────────
async function sendMessage(
  accessToken: string,
  phoneNumberId: string,
  params: any
): Promise<any> {
  const { to, type, text, image, video, document: doc, audio, location, contacts, interactive } = params;

  if (!to) throw new Error("Missing 'to' phone number");

  const payload: any = {
    messaging_product: "whatsapp",
    to: to.replace(/^\+/, ""),
    type: type || "text",
  };

  switch (payload.type) {
    case "text":
      payload.text = { body: text || "" };
      break;
    case "image":
      payload.image = image;
      break;
    case "video":
      payload.video = video;
      break;
    case "document":
      payload.document = doc;
      break;
    case "audio":
      payload.audio = audio;
      break;
    case "location":
      payload.location = location;
      break;
    case "contacts":
      payload.contacts = contacts;
      break;
    case "interactive":
      payload.interactive = interactive;
      break;
  }

  return await metaApi(accessToken, `${phoneNumberId}/messages`, "POST", payload);
}

// ─── Send Template Message ───────────────────────────────────────
async function sendTemplate(
  accessToken: string,
  phoneNumberId: string,
  params: any
): Promise<any> {
  const { to, template_name, language, components } = params;

  if (!to || !template_name) throw new Error("Missing 'to' or 'template_name'");

  const payload = {
    messaging_product: "whatsapp",
    to: to.replace(/^\+/, ""),
    type: "template",
    template: {
      name: template_name,
      language: { code: language || "en" },
      ...(components ? { components } : {}),
    },
  };

  return await metaApi(accessToken, `${phoneNumberId}/messages`, "POST", payload);
}

// ─── Mark as Read ────────────────────────────────────────────────
async function markAsRead(
  accessToken: string,
  phoneNumberId: string,
  messageId: string
): Promise<any> {
  if (!messageId) throw new Error("Missing message_id");

  return await metaApi(accessToken, `${phoneNumberId}/messages`, "POST", {
    messaging_product: "whatsapp",
    status: "read",
    message_id: messageId,
  });
}

// ─── Get Business Profile ────────────────────────────────────────
async function getBusinessProfile(
  accessToken: string,
  phoneNumberId: string
): Promise<any> {
  return await metaApi(
    accessToken,
    `${phoneNumberId}/whatsapp_business_profile?fields=about,address,description,email,profile_picture_url,websites,vertical`
  );
}

// ─── Update Business Profile ─────────────────────────────────────
async function updateBusinessProfile(
  accessToken: string,
  phoneNumberId: string,
  profile: any
): Promise<any> {
  if (!profile) throw new Error("Missing profile data");

  return await metaApi(accessToken, `${phoneNumberId}/whatsapp_business_profile`, "POST", {
    messaging_product: "whatsapp",
    ...profile,
  });
}

// ─── Create Template ─────────────────────────────────────────────
async function createTemplate(
  accessToken: string,
  wabaId: string,
  template: any,
  phoneNumberId?: string
): Promise<any> {
  if (!wabaId) throw new Error("WABA ID required to manage templates");
  if (!template) throw new Error("Missing template data");

  // Check if template has media header that needs a handle
  if (template.components) {
    for (const comp of template.components) {
      if (comp.type === 'HEADER' && ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(comp.format) && comp.media_url) {
        console.log(`Uploading media for ${comp.format} header: ${comp.media_url}`);
        
        // Download the file from Supabase storage
        const fileResponse = await fetch(comp.media_url);
        if (!fileResponse.ok) throw new Error(`Failed to download media: ${fileResponse.status}`);
        const fileBlob = await fileResponse.blob();
        const contentType = fileResponse.headers.get('content-type') || 'application/octet-stream';
        
        // Create resumable upload session using the app's upload endpoint
        // First, get the app ID from the access token
        const debugResp = await fetch(`https://graph.facebook.com/${GRAPH_API_VERSION}/debug_token?input_token=${accessToken}`, {
          headers: { Authorization: `Bearer ${accessToken}` }
        });
        const debugData = await debugResp.json();
        const appId = debugData?.data?.app_id;
        
        if (!appId) {
          console.log("Could not get app_id, trying direct upload approach");
          // Fallback: skip media sample for now, template may still work for TEXT-only
          delete comp.media_url;
          continue;
        }
        
        console.log("App ID:", appId);
        
        // Create upload session
        const sessionResp = await fetch(
          `https://graph.facebook.com/${GRAPH_API_VERSION}/${appId}/uploads?file_length=${fileBlob.size}&file_type=${encodeURIComponent(contentType)}&access_token=${accessToken}`,
          { method: "POST" }
        );
        const sessionData = await sessionResp.json();
        if (!sessionResp.ok) {
          console.error("Session create error:", JSON.stringify(sessionData));
          throw new Error(sessionData.error?.message || "Failed to create upload session");
        }
        const uploadSessionId = sessionData.id;
        console.log("Upload session created:", uploadSessionId);
        
        // Upload file bytes
        const fileBuffer = await fileBlob.arrayBuffer();
        const uploadResp = await fetch(
          `https://graph.facebook.com/${GRAPH_API_VERSION}/${uploadSessionId}`,
          {
            method: "POST",
            headers: {
              Authorization: `OAuth ${accessToken}`,
              "file_offset": "0",
              "Content-Type": contentType
            },
            body: fileBuffer
          }
        );
        const uploadData = await uploadResp.json();
        if (!uploadResp.ok) {
          console.error("Upload error:", JSON.stringify(uploadData));
          throw new Error(uploadData.error?.message || "Failed to upload file");
        }
        const fileHandle = uploadData.h;
        console.log("File uploaded, handle:", fileHandle);
        
        // Set example with handle
        comp.example = { header_handle: [fileHandle] };
        delete comp.media_url;
      }
    }
  }

  console.log("Creating template:", JSON.stringify(template, null, 2));
  return await metaApi(accessToken, `${wabaId}/message_templates`, "POST", template);
}

// ─── Get Templates ───────────────────────────────────────────────
async function getTemplates(
  accessToken: string,
  wabaId: string,
  limit = 100,
  after?: string
): Promise<any> {
  if (!wabaId) throw new Error("WABA ID required to manage templates");

  let endpoint = `${wabaId}/message_templates?limit=${limit}&fields=name,status,category,language,components,quality_score`;
  if (after) endpoint += `&after=${after}`;

  return await metaApi(accessToken, endpoint);
}

// ─── Delete Template ─────────────────────────────────────────────
async function deleteTemplate(
  accessToken: string,
  wabaId: string,
  templateName: string
): Promise<any> {
  if (!wabaId) throw new Error("WABA ID required to manage templates");
  if (!templateName) throw new Error("Missing template_name");

  return await metaApi(accessToken, `${wabaId}/message_templates?name=${templateName}`, "DELETE");
}

// ─── Get Media URL ───────────────────────────────────────────────
async function getMediaUrl(accessToken: string, mediaId: string): Promise<any> {
  if (!mediaId) throw new Error("Missing media_id");
  return await metaApi(accessToken, mediaId);
}

// ─── Upload Media ────────────────────────────────────────────────
async function uploadMedia(
  accessToken: string,
  phoneNumberId: string,
  fileUrl: string,
  mimeType: string
): Promise<any> {
  if (!fileUrl || !mimeType) throw new Error("Missing file_url or mime_type");

  // Download the file first
  const fileResponse = await fetch(fileUrl);
  const fileBlob = await fileResponse.blob();

  const formData = new FormData();
  formData.append("messaging_product", "whatsapp");
  formData.append("type", mimeType);
  formData.append("file", fileBlob);

  const response = await fetch(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/${phoneNumberId}/media`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}` },
      body: formData,
    }
  );

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error?.message || `Upload failed: ${response.status}`);
  }
  return data;
}

// ─── Get Phone Numbers ───────────────────────────────────────────
async function getPhoneNumbers(accessToken: string, wabaId: string): Promise<any> {
  if (!wabaId) throw new Error("WABA ID required");
  return await metaApi(
    accessToken,
    `${wabaId}/phone_numbers?fields=verified_name,code_verification_status,display_phone_number,quality_rating,platform_type,throughput,name_status`
  );
}

// ─── Test Connection ─────────────────────────────────────────────
async function testConnection(accessToken: string, phoneNumberId: string): Promise<any> {
  const data = await metaApi(
    accessToken,
    `${phoneNumberId}?fields=verified_name,display_phone_number,quality_rating,platform_type`
  );
  return { connected: true, ...data };
}

// ─── Send Single Message with Retry (handles rate limits) ────────
async function sendWithRetry(
  accessToken: string,
  phoneNumberId: string,
  payload: any,
  maxRetries = 3
): Promise<any> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await metaApi(accessToken, `${phoneNumberId}/messages`, "POST", payload);
    } catch (err: any) {
      const msg = err.message || "";
      const isRateLimit = msg.includes("code: 130429") || msg.includes("rate") || msg.includes("throttl") || msg.includes("Too many");
      const isTransient = msg.includes("code: 131026") || msg.includes("code: 131000") || msg.includes("temporarily") || msg.includes("timeout") || msg.includes("ETIMEDOUT") || msg.includes("Media upload") || msg.includes("Something went wrong");
      const isEcosystem = msg.includes("ecosystem") || msg.includes("131049") || msg.includes("healthy ecosystem");

      // Ecosystem errors are quality-based — retrying immediately won't help
      // Let the caller handle them (defer for later)
      if (isEcosystem) throw err;

      if ((isRateLimit || isTransient) && attempt < maxRetries) {
        // Exponential backoff: 2s, 4s, 8s
        const delay = Math.pow(2, attempt + 1) * 1000;
        console.log(`[Broadcast] Retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries}): ${isRateLimit ? 'rate-limit' : 'transient'}`);
        await new Promise((r) => setTimeout(r, delay));
        continue;
      }
      throw err;
    }
  }
}

// ─── Insert broadcast messages into wa_messages (Live Chat) ─────────────────
// Finds or creates a conversation for each phone, then inserts the message
// with full template content (body text, media, etc.) so chat shows real content.
async function insertChatMessages(
  supabase: any,
  wa_account_id: string,
  template_name: string,
  sentItems: { phone: string; whatsapp_message_id: string; sent_at: string }[]
) {
  if (sentItems.length === 0 || !wa_account_id) return;
  try {
    // ─── Lookup template content from DB ───
    let templateBody = "";
    let templateMediaUrl = "";
    let templateMediaMime = "";
    let templateHeaderType = "";
    try {
      const { data: tpl } = await supabase
        .from("wa_templates")
        .select("body_text, header_type, header_content")
        .eq("name", template_name)
        .eq("wa_account_id", wa_account_id)
        .limit(1)
        .single();
      if (tpl) {
        templateBody = tpl.body_text || "";
        templateHeaderType = tpl.header_type || "";
        if (tpl.header_content) {
          templateMediaUrl = tpl.header_content;
          if (templateHeaderType === "document") templateMediaMime = "application/pdf";
          else if (templateHeaderType === "image") templateMediaMime = "image/jpeg";
          else if (templateHeaderType === "video") templateMediaMime = "video/mp4";
        }
      }
    } catch (_) {
      // Template lookup failed — fall back to basic content
    }

    const msgType = ["document", "image", "video"].includes(templateHeaderType)
      ? templateHeaderType
      : "template";

    // Normalize phones to +966... format for conversations
    const phones = sentItems.map(s => {
      const clean = s.phone.replace(/^\+/, "").replace(/\D/g, "");
      return `+${clean}`;
    });

    // Lookup customer names from customers table (uses no-plus format: 966...)
    const rawPhones = phones.map(p => p.replace(/^\+/, ""));
    const customerNameMap: Record<string, string> = {};
    for (let c = 0; c < rawPhones.length; c += 500) {
      const chunk = rawPhones.slice(c, c + 500);
      const { data: customers } = await supabase
        .from("customers")
        .select("name, whatsapp_number")
        .in("whatsapp_number", chunk);
      if (customers) {
        for (const cust of customers) {
          if (cust.name && cust.whatsapp_number) {
            customerNameMap[`+${cust.whatsapp_number}`] = cust.name;
          }
        }
      }
    }

    // Batch lookup existing conversations
    const { data: existingConvs } = await supabase
      .from("wa_conversations")
      .select("id, customer_phone")
      .eq("wa_account_id", wa_account_id)
      .eq("status", "active")
      .in("customer_phone", phones);

    const convMap: Record<string, string> = {};
    if (existingConvs) {
      for (const c of existingConvs) {
        convMap[c.customer_phone] = c.id;
      }
    }

    // Create conversations for phones that don't have one
    const missingPhones = phones.filter(p => !convMap[p]);
    if (missingPhones.length > 0) {
      const inserts = missingPhones.map(phone => ({
        wa_account_id,
        customer_phone: phone,
        customer_name: customerNameMap[phone] || phone,
        status: "active",
        handled_by: "bot",
        is_bot_handling: true,
        bot_type: "ai",
        last_message_at: new Date().toISOString(),
        unread_count: 0,
      }));
      const { data: newConvs } = await supabase
        .from("wa_conversations")
        .upsert(inserts, { onConflict: "wa_account_id,customer_phone" })
        .select("id, customer_phone");
      if (newConvs) {
        for (const c of newConvs) {
          convMap[c.customer_phone] = c.id;
        }
      }
    }

    // Insert wa_messages with full template content
    const msgInserts = sentItems.map(s => {
      const phone = `+${s.phone.replace(/^\+/, "").replace(/\D/g, "")}`;
      const msg: Record<string, any> = {
        conversation_id: convMap[phone],
        wa_account_id,
        direction: "outbound",
        message_type: msgType,
        content: templateBody || `📢 Broadcast: ${template_name}`,
        template_name,
        whatsapp_message_id: s.whatsapp_message_id,
        status: "sent",
        sent_by: "broadcast",
        created_at: s.sent_at,
      };
      if (templateMediaUrl) {
        msg.media_url = templateMediaUrl;
        msg.media_mime_type = templateMediaMime;
      }
      return msg;
    }).filter(m => m.conversation_id); // only insert if we have a conversation

    if (msgInserts.length > 0) {
      await supabase.from("wa_messages").insert(msgInserts);

      // Update last_message_preview on conversations so chat list shows the message
      const preview = (templateBody || `📢 Broadcast: ${template_name}`).substring(0, 100);
      const convIds = [...new Set(msgInserts.map(m => m.conversation_id).filter(Boolean))];
      for (let c = 0; c < convIds.length; c += 500) {
        const chunk = convIds.slice(c, c + 500);
        await supabase
          .from("wa_conversations")
          .update({ last_message_preview: preview, last_message_at: new Date().toISOString() })
          .in("id", chunk);
      }
    }
  } catch (chatErr: any) {
    console.error(`[Broadcast] Chat message insert error (non-fatal):`, chatErr?.message);
  }
}

// ─── Backfill sweep: finds sent recipients missing wa_message entries ───────
// Safety net for fire-and-forget insertChatMessages calls that failed silently.
async function backfillMissingChatMessages(
  supabase: any,
  wa_account_id: string,
  template_name: string,
  broadcast_id: string
): Promise<number> {
  try {
    const { data: sentRecips } = await supabase
      .from("wa_broadcast_recipients")
      .select("phone_number, whatsapp_message_id, sent_at")
      .eq("broadcast_id", broadcast_id)
      .in("status", ["sent", "delivered", "read"])
      .not("whatsapp_message_id", "is", null);
    if (!sentRecips || sentRecips.length === 0) return 0;

    const wamIds = sentRecips.map((r: any) => r.whatsapp_message_id).filter(Boolean);
    const existingIds = new Set<string>();
    for (let c = 0; c < wamIds.length; c += 500) {
      const chunk = wamIds.slice(c, c + 500);
      const { data: existing } = await supabase
        .from("wa_messages")
        .select("whatsapp_message_id")
        .in("whatsapp_message_id", chunk);
      if (existing) existing.forEach((m: any) => existingIds.add(m.whatsapp_message_id));
    }

    const missing = sentRecips.filter((r: any) => !existingIds.has(r.whatsapp_message_id));
    if (missing.length === 0) return 0;

    console.log(`[Broadcast] Backfill sweep: ${missing.length} sent messages missing from wa_messages, inserting...`);
    const chatItems = missing.map((r: any) => ({
      phone: r.phone_number,
      whatsapp_message_id: r.whatsapp_message_id,
      sent_at: r.sent_at || new Date().toISOString(),
    }));
    await insertChatMessages(supabase, wa_account_id, template_name, chatItems);
    console.log(`[Broadcast] Backfill sweep: inserted ${missing.length} chat messages`);
    return missing.length;
  } catch (err: any) {
    console.error(`[Broadcast] Backfill sweep error (non-fatal):`, err?.message);
    return 0;
  }
}

// ─── Send Broadcast ──────────────────────────────────────────────
async function sendBroadcast(
  supabase: any,
  accessToken: string,
  phoneNumberId: string,
  params: any
): Promise<any> {
  const { broadcast_id, template_name, language, components, cached_media_id } = params;
  const wa_account_id = params.account_id;
  let { recipients } = params;

  if (!broadcast_id || !template_name) {
    throw new Error("Missing broadcast_id or template_name");
  }

  // ─── SAFETY: 60s wall-clock limit ───
  // The Deno edge-runtime kills workers at ~150s.
  // We stop at 60s to guarantee safe auto-continue self-invocation.
  const MAX_EXECUTION_MS = 50_000; // Trigger auto-continue much earlier to chain sends
  const functionStartTime = Date.now();

  // If recipients not passed (large broadcast), read them from DB directly
  // Paginate in chunks of 5000 to bypass PostgREST default 1000 row limit
  if (!recipients || !Array.isArray(recipients) || recipients.length === 0) {
    console.log(`[Broadcast] No recipients in request body, reading from DB...`);
    recipients = [];
    const PAGE_SIZE = 5000;
    let page = 0;
    while (true) {
      const { data: dbRecipients, error: dbErr } = await supabase
        .from("wa_broadcast_recipients")
        .select("id, phone_number")
        .eq("broadcast_id", broadcast_id)
        .eq("status", "pending")
        .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
      
      if (dbErr) throw new Error("Failed to load recipients: " + dbErr.message);
      const batch = (dbRecipients || []).map((r: any) => ({ id: r.id, phone: r.phone_number }));
      recipients.push(...batch);
      if (batch.length < PAGE_SIZE) break; // last page
      page++;
    }
    console.log(`[Broadcast] Loaded ${recipients.length} pending recipients from DB (${page + 1} pages)`);
  }

  console.log(`[Broadcast] Starting: template=${template_name}, lang=${language}, recipients=${recipients?.length}, hasComponents=${!!components}`);
  if (components) console.log(`[Broadcast] Components:`, JSON.stringify(components));

  // ─── Pre-upload media to WhatsApp ───
  // Instead of passing a URL link for each message (which forces Meta to download
  // the file thousands of times from our server, causing "Media upload error"),
  // we upload the media ONCE to WhatsApp's servers and use the returned media_id.
  // ─── Pre-upload media to WhatsApp (with caching across invocations) ───
  // Upload once on first invocation, then pass cached_media_id to auto-continues.
  let processedComponents = components;
  let resolvedMediaId = cached_media_id || null;

  if (components && Array.isArray(components)) {
    processedComponents = JSON.parse(JSON.stringify(components)); // deep clone
    for (const comp of processedComponents) {
      if (comp.type === 'header' && Array.isArray(comp.parameters)) {
        for (const param of comp.parameters) {
          const mediaType = param.type; // 'image', 'video', 'document'
          const mediaObj = param[mediaType];
          if (mediaObj && mediaObj.link && !mediaObj.id) {
            // If we already have a cached media_id from a previous invocation, reuse it
            if (resolvedMediaId) {
              console.log(`[Broadcast] Using cached media_id=${resolvedMediaId} (skipping re-upload)`);
              delete mediaObj.link;
              mediaObj.id = resolvedMediaId;
            } else {
              try {
                console.log(`[Broadcast] Pre-uploading ${mediaType} to WhatsApp: ${mediaObj.link}`);
                
                // Download the file from our storage
                const fileResp = await fetch(mediaObj.link);
                if (!fileResp.ok) throw new Error(`Download failed: ${fileResp.status}`);
                const fileBlob = await fileResp.blob();
                const contentType = fileResp.headers.get('content-type') || 'application/octet-stream';
                
                // Upload to WhatsApp via Media API
                const formData = new FormData();
                formData.append('messaging_product', 'whatsapp');
                formData.append('type', contentType);
                formData.append('file', fileBlob, mediaObj.filename || 'file');
                
                const uploadResp = await fetch(
                  `https://graph.facebook.com/${GRAPH_API_VERSION}/${phoneNumberId}/media`,
                  {
                    method: 'POST',
                    headers: { Authorization: `Bearer ${accessToken}` },
                    body: formData,
                  }
                );
                const uploadData = await uploadResp.json();
                if (!uploadResp.ok) {
                  throw new Error(uploadData.error?.message || `Upload failed: ${uploadResp.status}`);
                }
                
                resolvedMediaId = uploadData.id;
                console.log(`[Broadcast] Media uploaded to WhatsApp, id=${resolvedMediaId}`);
                
                // Replace link with id — WhatsApp serves the file from their CDN now
                delete mediaObj.link;
                mediaObj.id = resolvedMediaId;
              } catch (uploadErr: any) {
                console.error(`[Broadcast] Media pre-upload failed, keeping link fallback:`, uploadErr.message);
                // Keep the original link as fallback
              }
            }
          }
        }
      }
    }
    console.log(`[Broadcast] Processed components:`, JSON.stringify(processedComponents));
  }

  // ─── Filter out unsubscribed customers (is_deleted = true) ───
  const allPhones = recipients.map((r: any) => (r.phone || "").replace(/^\+/, "").replace(/\D/g, "")).filter(Boolean);
  const allPhonesWithPlus = allPhones.map((p: string) => `+${p}`);
  const phoneLookup = [...allPhones, ...allPhonesWithPlus];

  let unsubscribedPhones = new Set<string>();
  if (phoneLookup.length > 0) {
    const LOOKUP_CHUNK = 500;
    for (let c = 0; c < phoneLookup.length; c += LOOKUP_CHUNK) {
      const chunk = phoneLookup.slice(c, c + LOOKUP_CHUNK);
      const { data: unsubs } = await supabase
        .from("customers")
        .select("whatsapp_number")
        .eq("is_deleted", true)
        .in("whatsapp_number", chunk);
      
      if (unsubs && unsubs.length > 0) {
        for (const u of unsubs) {
          const clean = (u.whatsapp_number || "").replace(/^\+/, "").replace(/\D/g, "");
          if (clean) unsubscribedPhones.add(clean);
        }
      }
    }
    if (unsubscribedPhones.size > 0) {
      console.log(`[Broadcast] Filtering out ${unsubscribedPhones.size} unsubscribed numbers`);
    }
  }

  // Mark unsubscribed recipients as 'skipped' in DB so they don't stay pending
  const unsubRecipientIds: string[] = [];
  const filteredRecipients: any[] = [];
  for (const r of recipients) {
    const clean = (r.phone || "").replace(/^\+/, "").replace(/\D/g, "");
    if (unsubscribedPhones.has(clean)) {
      if (r.id) unsubRecipientIds.push(r.id);
    } else {
      filteredRecipients.push(r);
    }
  }

  // Bulk-mark unsubscribed as skipped
  if (unsubRecipientIds.length > 0) {
    const SKIP_CHUNK = 200;
    for (let c = 0; c < unsubRecipientIds.length; c += SKIP_CHUNK) {
      const chunk = unsubRecipientIds.slice(c, c + SKIP_CHUNK);
      await supabase
        .from("wa_broadcast_recipients")
        .update({ status: "failed", error_details: "Unsubscribed (is_deleted)" })
        .in("id", chunk);
    }
    console.log(`[Broadcast] Marked ${unsubRecipientIds.length} unsubscribed recipients as skipped`);
  }

  const skippedCount = recipients.length - filteredRecipients.length;

  // Update broadcast status to sending
  await supabase
    .from("wa_broadcasts")
    .update({ status: "sending" })
    .eq("id", broadcast_id);

  let sentCount = 0;
  let failedCount = 0;
  let ecosystemFailCount = 0;
  let rateLimitHits = 0;
  let timedOut = false;

  // ─── PREMIUM BROADCAST ENGINE ───
  // Target: 10,000 messages in 10 minutes (~17 msg/s)
  // Cruising at ~20 msg/s to leave buffer for throttle pauses.
  //
  // 1. WARM-UP RAMP: Start at 5 concurrency/800ms, ramp to 20 concurrency/300ms
  //    over 15 batches. Meta flags sudden bursts — gradual ramp avoids it.
  //
  // 2. ECOSYSTEM AUTO-THROTTLE: When ecosystem errors appear:
  //    - Immediately cut speed by 50%
  //    - Add cooldown pause (3-15s based on severity)
  //    - If >10% ecosystem fail rate in rolling window → full pause 20s
  //    - If 8+ consecutive ecosystem fails → emergency pause 30s
  //
  // 3. ROLLING WINDOW: Track last 100 sends for real-time decisions.
  //
  // 4. ECOSYSTEM FAILURES → DEFERRED: Keep as 'pending' for next auto-continue
  //    invocation. These are quality-based, not transient — retrying hours later
  //    when Meta's quality score resets is the correct approach.

  // Speed control state (AGGRESSIVE MODE)
  let concurrency = 20;           // Start even closer to max (was 15)
  let delayMs = 50;               // 50ms between batches (20x faster than original 800ms)
  const MAX_CONCURRENCY = 50;     // Higher ceiling (was 35, originally 20)
  const MIN_CONCURRENCY = 2;      // Minimum during throttle (never fully stop)
  const RAMP_UP_BATCHES = 1;      // Minimal ramp-up (was 3, straight to full speed)
  let batchesSent = 0;

  // Ecosystem monitoring (rolling window)
  const WINDOW_SIZE = 100;        // Last N sends to monitor
  const rollingWindow: boolean[] = [];
  let consecutiveEcosystemFails = 0;
  let lastEcosystemPause = 0;

  const startTime = Date.now();

  // Helper: flush a batch of sent updates to DB immediately using parallel updates
  async function flushSentBatch(batch: { id: string; whatsapp_message_id: string; sent_at: string }[]) {
    if (batch.length === 0) return;
    // Fire all updates in parallel (batch is max ~20 items = concurrency size)
    await Promise.all(batch.map((item) =>
      supabase
        .from("wa_broadcast_recipients")
        .update({
          status: "sent",
          whatsapp_message_id: item.whatsapp_message_id,
          sent_at: item.sent_at,
        })
        .eq("id", item.id)
    ));
  }

  // Helper: flush a batch of failed updates to DB immediately
  async function flushFailedBatch(batch: { id: string; error_details: string }[]) {
    if (batch.length === 0) return;
    await Promise.all(batch.map((item) =>
      supabase
        .from("wa_broadcast_recipients")
        .update({
          status: "failed",
          error_details: item.error_details,
        })
        .eq("id", item.id)
    ));
  }

  // Process recipients in concurrent batches with premium adaptive speed
  for (let i = 0; i < filteredRecipients.length; i += concurrency) {
    // ─── Time check BEFORE each batch ───
    const elapsed = Date.now() - functionStartTime;
    if (elapsed >= MAX_EXECUTION_MS) {
      const remaining = filteredRecipients.length - i;
      console.log(`[Broadcast] ⏱️ TIME CHECK (${(elapsed/1000).toFixed(0)}s/${(MAX_EXECUTION_MS/1000).toFixed(0)}s). ${remaining} pending. Auto-continuing...`);
      timedOut = true;
      break;
    }

    const batch = filteredRecipients.slice(i, i + concurrency);
    let batchRateLimited = 0;
    let batchEcosystemFails = 0;

    const results = await Promise.allSettled(
      batch.map(async (recipient: any) => {
        const phone = recipient.phone?.replace(/^\+/, "") || "";
        if (!phone) throw new Error("No phone number");

        const payload = {
          messaging_product: "whatsapp",
          to: phone,
          type: "template",
          template: {
            name: template_name,
            language: { code: language || "en" },
            ...(processedComponents ? { components: processedComponents } : {}),
          },
        };

        const result = await sendWithRetry(accessToken, phoneNumberId, payload);
        return { recipient, waMessageId: result.messages?.[0]?.id };
      })
    );

    // Collect results and flush to DB immediately
    const now = new Date().toISOString();
    const batchSent: { id: string; whatsapp_message_id: string; sent_at: string }[] = [];
    const batchFailed: { id: string; error_details: string }[] = [];
    const batchEcosystem: { id: string; error_details: string }[] = [];

    for (let j = 0; j < results.length; j++) {
      const res = results[j];
      if (res.status === "fulfilled") {
        sentCount++;
        consecutiveEcosystemFails = 0;
        rollingWindow.push(true);
        if (rollingWindow.length > WINDOW_SIZE) rollingWindow.shift();
        if (res.value.recipient.id) {
          batchSent.push({
            id: res.value.recipient.id,
            whatsapp_message_id: res.value.waMessageId || "",
            sent_at: now,
          });
        }
      } else {
        const errMsg = res.reason?.message || "Send failed";
        const isRateLimit = errMsg.includes("130429") || errMsg.includes("rate") || errMsg.includes("throttl");
        const isEcosystem = errMsg.includes("ecosystem") || errMsg.includes("131049") || errMsg.includes("healthy ecosystem");
        const recipient = batch[j];

        if (isEcosystem) {
          // ─── ECOSYSTEM ERROR: Defer, but cap retries to prevent infinite loops ───
          batchEcosystemFails++;
          ecosystemFailCount++;
          consecutiveEcosystemFails++;
          rollingWindow.push(false);
          if (rollingWindow.length > WINDOW_SIZE) rollingWindow.shift();
          if (recipient?.id) {
            // Check existing retry count in error_details
            const currentErrors = recipient.error_details || '';
            const retryMatch = currentErrors.match(/\[RETRY:(\d+)\]/);
            const retryCount = retryMatch ? parseInt(retryMatch[1]) : 0;
            
            if (retryCount < 2) {
              // First 2 retries: defer to pending with retry counter
              batchEcosystem.push({
                id: recipient.id,
                error_details: `${errMsg.substring(0, 900)} [RETRY:${retryCount + 1}]`,
              });
            } else {
              // After 2 retries: give up and mark as failed
              batchFailed.push({
                id: recipient.id,
                error_details: `Ecosystem error - retried ${retryCount} times: ${errMsg.substring(0, 850)}`,
              });
            }
          }
        } else if (isRateLimit) {
          batchRateLimited++;
          rateLimitHits++;
          failedCount++;
          if (recipient?.id) {
            batchFailed.push({ id: recipient.id, error_details: errMsg.substring(0, 1000) });
          }
        } else {
          failedCount++;
          if (recipient?.id) {
            batchFailed.push({ id: recipient.id, error_details: errMsg.substring(0, 1000) });
          }
        }
        console.error(`Broadcast send failed for ${recipient?.phone}:`, errMsg.substring(0, 200));
      }
    }

    // ─── IMMEDIATE DB flush ───
    const dbOps: Promise<any>[] = [flushSentBatch(batchSent), flushFailedBatch(batchFailed)];
    // Ecosystem failures: mark as 'pending' so auto-continue will retry them later
    // But add error_details so we know WHY they were deferred
    if (batchEcosystem.length > 0) {
      dbOps.push(Promise.all(batchEcosystem.map(item =>
        supabase.from("wa_broadcast_recipients")
          .update({ status: "pending", error_details: `ECOSYSTEM_DEFERRED: ${item.error_details}` })
          .eq("id", item.id)
      )));
    }
    await Promise.all(dbOps);

    // ─── Insert sent messages into Live Chat ───
    const chatItems = batchSent.map((s, idx) => ({
      phone: batch[idx]?.phone || "",
      whatsapp_message_id: s.whatsapp_message_id,
      sent_at: s.sent_at,
    })).filter(c => c.phone);
    insertChatMessages(supabase, wa_account_id, template_name, chatItems).catch(() => {});

    // ─── Update broadcast counts ───
    await supabase
      .from("wa_broadcasts")
      .update({
        sent_count: sentCount,
        failed_count: failedCount + skippedCount,
      })
      .eq("id", broadcast_id);

    batchesSent++;

    // ═══════════════════════════════════════════════════════════════
    // PREMIUM ADAPTIVE SPEED CONTROL
    // Target: 10K msgs / 10 min → ~17 msg/s → cruise at 20 msg/s
    // ═══════════════════════════════════════════════════════════════

    // Calculate rolling ecosystem fail rate
    const windowFails = rollingWindow.filter(x => !x).length;
    const windowRate = rollingWindow.length > 0 ? windowFails / rollingWindow.length : 0;

    // ─── ECOSYSTEM THROTTLE ───
    if (batchEcosystemFails > 0) {
      const now_ts = Date.now();

      if (windowRate > 0.10 || consecutiveEcosystemFails >= 8) {
        // CRITICAL: >10% ecosystem fail rate or 8+ consecutive → emergency pause (capped at 10s)
        const pauseMs = Math.min(10000, 3000 * Math.ceil(consecutiveEcosystemFails / 4));
        console.log(`[Broadcast] 🛑 ECOSYSTEM CRITICAL: ${(windowRate*100).toFixed(0)}% fail rate, ${consecutiveEcosystemFails} consecutive. Pausing ${pauseMs/1000}s (capped)`);
        concurrency = MIN_CONCURRENCY;
        delayMs = 1500;
        lastEcosystemPause = now_ts;
        await new Promise(r => setTimeout(r, pauseMs));
        // If still critical, force early auto-continue instead of retrying in same cycle
        if (windowRate > 0.15 || consecutiveEcosystemFails >= 10) {
          console.log(`[Broadcast] 🔴 SEVERE ecosystem issues detected. Invoking auto-continue early.`);
          timedOut = true;
          break; // Exit loop to force auto-continue
        }
      } else if (windowRate > 0.05 || consecutiveEcosystemFails >= 3) {
        // MODERATE: >5% fail rate or 3+ consecutive → slow down significantly
        const oldC = concurrency;
        concurrency = Math.max(MIN_CONCURRENCY, Math.floor(concurrency * 0.5));
        delayMs = Math.min(2000, delayMs + 300);
        lastEcosystemPause = now_ts;
        console.log(`[Broadcast] ⚠️ ECOSYSTEM THROTTLE: ${batchEcosystemFails} in batch, ${(windowRate*100).toFixed(0)}% rate. c:${oldC}→${concurrency}, d→${delayMs}ms`);
        await new Promise(r => setTimeout(r, 5000));
      } else {
        // LIGHT: occasional ecosystem error — minor slowdown
        const oldC = concurrency;
        concurrency = Math.max(MIN_CONCURRENCY, concurrency - 2);
        delayMs = Math.min(1500, delayMs + 100);
        console.log(`[Broadcast] ⚠️ ECOSYSTEM LIGHT: ${batchEcosystemFails} in batch. c:${oldC}→${concurrency}, d→${delayMs}ms`);
        await new Promise(r => setTimeout(r, 2000));
      }
    }
    // ─── RATE LIMIT THROTTLE ───
    else if (batchRateLimited > 0) {
      const oldC = concurrency;
      concurrency = Math.max(MIN_CONCURRENCY, Math.floor(concurrency * 0.5));
      delayMs = Math.min(2000, delayMs + 500);
      console.log(`[Broadcast] Rate limited ${batchRateLimited}x, c:${oldC}→${concurrency}, d→${delayMs}ms`);
      await new Promise(r => setTimeout(r, 5000));
    }
    // ─── WARM-UP RAMP (5→8→11→14→17→20 concurrency, 800→300ms delay) ───
    else if (batchesSent <= RAMP_UP_BATCHES) {
      const progress = batchesSent / RAMP_UP_BATCHES;
      const targetC = Math.min(MAX_CONCURRENCY, 5 + Math.floor(progress * (MAX_CONCURRENCY - 5)));
      const targetDelay = Math.max(300, 800 - Math.floor(progress * 500));
      if (targetC > concurrency || targetDelay < delayMs) {
        concurrency = targetC;
        delayMs = targetDelay;
        console.log(`[Broadcast] 📈 RAMP-UP ${batchesSent}/${RAMP_UP_BATCHES}: c→${concurrency}, d→${delayMs}ms (~${(concurrency / (delayMs/1000 + 0.3)).toFixed(0)} msg/s)`);
      }
    }
    // ─── RECOVERY after ecosystem pause ───
    else if (Date.now() - lastEcosystemPause > 10000 && concurrency < MAX_CONCURRENCY && windowRate < 0.03) {
      // 10s since last pause + <3% fail rate → ramp back up aggressively
      const oldC = concurrency;
      concurrency = Math.min(MAX_CONCURRENCY, concurrency + 3);
      delayMs = Math.max(300, delayMs - 150);
      console.log(`[Broadcast] 📈 RECOVERY: c:${oldC}→${concurrency}, d→${delayMs}ms (eco rate: ${(windowRate*100).toFixed(0)}%)`);
    }

    // Log progress every 200 messages
    const processed = Math.min(i + batch.length, filteredRecipients.length);
    if (processed % 200 < concurrency || processed === filteredRecipients.length) {
      const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);
      const rate = (sentCount / (Date.now() - startTime) * 1000).toFixed(1);
      const remaining = filteredRecipients.length - processed;
      const eta = sentCount > 0 ? ((remaining / (sentCount / ((Date.now() - startTime) / 1000)))).toFixed(0) : '?';
      console.log(`[Broadcast] ${processed}/${filteredRecipients.length} | sent:${sentCount} eco:${ecosystemFailCount} fail:${failedCount} | ${elapsedSec}s | ${rate} msg/s | ETA:${eta}s | c=${concurrency} d=${delayMs}ms | eco_rate:${(windowRate*100).toFixed(0)}%`);
    }

    // Inter-batch delay
    if (i + concurrency < filteredRecipients.length) {
      await new Promise(r => setTimeout(r, delayMs));
    }
  }

  const totalTime = ((Date.now() - startTime) / 1000).toFixed(1);
  const avgRate = (sentCount / Math.max(1, (Date.now() - startTime) / 1000)).toFixed(1);

  if (timedOut) {
    // ─── Partial completion — outer .then() handler will auto-continue ───
    console.log(`[Broadcast] PARTIAL in ${totalTime}s (${avgRate} msg/s) | sent:${sentCount} eco_defer:${ecosystemFailCount} failed:${failedCount} skipped:${skippedCount} | Returning for auto-continue...`);
    await supabase
      .from("wa_broadcasts")
      .update({
        status: "sending",
        sent_count: sentCount,
        failed_count: failedCount + skippedCount,
      })
      .eq("id", broadcast_id);
    // NOTE: Auto-continue is handled ONLY in the case handler's .then() callback
    // to prevent duplicate chains (which cause exponential worker spawning)
  } else {
    // ─── Full completion — backfill missing chat messages then recount ───
    console.log(`[Broadcast] ✅ COMPLETE in ${totalTime}s (${avgRate} msg/s) | sent:${sentCount} eco_defer:${ecosystemFailCount} failed:${failedCount} skipped:${skippedCount}`);

    // Safety-net: find any sent recipients whose wa_message was lost by fire-and-forget
    await backfillMissingChatMessages(supabase, wa_account_id, template_name, broadcast_id);

    const { data: finalCounts } = await supabase
      .from("wa_broadcast_recipients")
      .select("status")
      .eq("broadcast_id", broadcast_id);
    const sc: any = {};
    if (finalCounts) finalCounts.forEach((r: any) => { sc[r.status] = (sc[r.status] || 0) + 1; });
    const totalSent = (sc.sent || 0) + (sc.delivered || 0) + (sc.read || 0);
    const totalFailed = sc.failed || 0;
    const totalPending = sc.pending || 0;
    const finalStatus = totalSent === 0 && totalFailed > 0 ? "failed" : totalPending > 0 ? "sending" : "completed";
    await supabase
      .from("wa_broadcasts")
      .update({
        status: finalStatus,
        sent_count: sc.sent || 0,
        failed_count: totalFailed,
        delivered_count: sc.delivered || 0,
        read_count: sc.read || 0,
        completed_at: finalStatus === 'completed' ? new Date().toISOString() : undefined,
      })
      .eq("id", broadcast_id);
  }

  return { sent: sentCount, failed: failedCount, ecosystem_deferred: ecosystemFailCount, skipped: skippedCount, rateLimitHits, total: recipients.length, timedOut, duration: `${totalTime}s`, avg_rate: `${avgRate} msg/s`, cached_media_id: resolvedMediaId };
}

// ─── Slow Ecosystem Retry ────────────────────────────────────────
// Sends ecosystem-failed messages at ~3 msg/s (concurrency=1, 333ms delay)
// to avoid triggering the ecosystem quality filter again.
// Auto-continues via the case handler if time limit is hit.
async function sendEcoRetry(
  supabase: any,
  accessToken: string,
  phoneNumberId: string,
  params: any
): Promise<any> {
  const { broadcast_id, template_name, language, components, cached_media_id } = params;
  const wa_account_id = params.account_id;

  if (!broadcast_id || !template_name) {
    throw new Error("Missing broadcast_id or template_name");
  }

  const MAX_EXECUTION_MS = 50_000; // 50s limit for self-hosted (more aggressive chaining)
  const functionStartTime = Date.now();
  const ECO_CONCURRENCY = 5;      // 5 parallel
  const ECO_DELAY_MS = 1500;      // 1.5s between batches → ~3 msg/s overall

  // Load ecosystem-failed recipients from DB
  // Also pick up any ECO_RETRY_IN_PROGRESS pending (from broken chains)
  const { data: ecoFailed, error: loadErr1 } = await supabase
    .from("wa_broadcast_recipients")
    .select("id, phone_number")
    .eq("broadcast_id", broadcast_id)
    .eq("status", "failed")
    .like("error_details", "%ecosystem%")
    .limit(5000);

  const { data: ecoPending, error: loadErr2 } = await supabase
    .from("wa_broadcast_recipients")
    .select("id, phone_number")
    .eq("broadcast_id", broadcast_id)
    .eq("status", "pending")
    .eq("error_details", "ECO_RETRY_IN_PROGRESS")
    .limit(5000);

  if (loadErr1) throw new Error("Failed to load eco recipients: " + loadErr1.message);
  const allEco = [...(ecoFailed || []), ...(ecoPending || [])];
  const recipients = allEco.map((r: any) => ({ id: r.id, phone: r.phone_number }));

  if (recipients.length === 0) {
    console.log(`[EcoRetry] No ecosystem-failed recipients to retry`);
    return { sent: 0, failed: 0, total: 0, timedOut: false };
  }

  console.log(`[EcoRetry] Starting slow retry: ${recipients.length} ecosystem-failed, template=${template_name}, ~3 msg/s`);

  // Reset them to 'pending' first so they're recognizable
  const recipientIds = recipients.map((r: any) => r.id);
  const CHUNK = 500;
  for (let c = 0; c < recipientIds.length; c += CHUNK) {
    await supabase
      .from("wa_broadcast_recipients")
      .update({ status: "pending", error_details: "ECO_RETRY_IN_PROGRESS" })
      .in("id", recipientIds.slice(c, c + CHUNK));
  }

  // ─── Pre-upload media (reuse cached_media_id if available) ───
  let processedComponents = components;
  let resolvedMediaId = cached_media_id || null;

  if (components && Array.isArray(components)) {
    processedComponents = JSON.parse(JSON.stringify(components));
    for (const comp of processedComponents) {
      if (comp.type === 'header' && Array.isArray(comp.parameters)) {
        for (const param of comp.parameters) {
          const mediaType = param.type;
          const mediaObj = param[mediaType];
          if (mediaObj && mediaObj.link && !mediaObj.id) {
            if (resolvedMediaId) {
              delete mediaObj.link;
              mediaObj.id = resolvedMediaId;
            } else {
              try {
                const fileResp = await fetch(mediaObj.link);
                if (!fileResp.ok) throw new Error(`Download failed: ${fileResp.status}`);
                const fileBlob = await fileResp.blob();
                const contentType = fileResp.headers.get('content-type') || 'application/octet-stream';
                const formData = new FormData();
                formData.append('messaging_product', 'whatsapp');
                formData.append('type', contentType);
                formData.append('file', fileBlob, mediaObj.filename || 'file');
                const uploadResp = await fetch(
                  `https://graph.facebook.com/${GRAPH_API_VERSION}/${phoneNumberId}/media`,
                  { method: 'POST', headers: { Authorization: `Bearer ${accessToken}` }, body: formData }
                );
                const uploadData = await uploadResp.json();
                if (!uploadResp.ok) throw new Error(uploadData.error?.message || `Upload failed`);
                resolvedMediaId = uploadData.id;
                delete mediaObj.link;
                mediaObj.id = resolvedMediaId;
                console.log(`[EcoRetry] Media uploaded, id=${resolvedMediaId}`);
              } catch (uploadErr: any) {
                console.error(`[EcoRetry] Media upload failed, using link fallback:`, uploadErr?.message);
              }
            }
          }
        }
      }
    }
  }

  let sentCount = 0;
  let failedCount = 0;
  let timedOut = false;

  // Send in parallel batches of ECO_CONCURRENCY, with ECO_DELAY_MS between batches
  for (let i = 0; i < recipients.length; i += ECO_CONCURRENCY) {
    const elapsed = Date.now() - functionStartTime;
    if (elapsed >= MAX_EXECUTION_MS) {
      console.log(`[EcoRetry] ⏱️ TIME LIMIT (${(elapsed/1000).toFixed(0)}s). ${recipients.length - i} remaining. Will auto-continue.`);
      timedOut = true;
      break;
    }

    const batch = recipients.slice(i, i + ECO_CONCURRENCY);

    const results = await Promise.allSettled(
      batch.map(async (recipient: any) => {
        const phone = (recipient.phone || "").replace(/^\+/, "");
        if (!phone) throw new Error("No phone");

        const payload = {
          messaging_product: "whatsapp",
          to: phone,
          type: "template",
          template: {
            name: template_name,
            language: { code: language || "en" },
            ...(processedComponents ? { components: processedComponents } : {}),
          },
        };

        const result = await sendWithRetry(accessToken, phoneNumberId, payload, 2);
        return { recipient, waMessageId: result.messages?.[0]?.id || "" };
      })
    );

    // Flush results to DB
    const now = new Date().toISOString();
    const dbOps: Promise<any>[] = [];

    for (let j = 0; j < results.length; j++) {
      const res = results[j];
      if (res.status === "fulfilled") {
        sentCount++;
        dbOps.push(
          supabase.from("wa_broadcast_recipients")
            .update({
              status: "sent",
              whatsapp_message_id: res.value.waMessageId,
              sent_at: now,
              error_details: null,
            })
            .eq("id", res.value.recipient.id)
        );
      } else {
        failedCount++;
        const errMsg = (res.reason?.message || "Send failed").substring(0, 1000);
        console.error(`[EcoRetry] Failed ${batch[j]?.phone}: ${errMsg.substring(0, 200)}`);
        dbOps.push(
          supabase.from("wa_broadcast_recipients")
            .update({ status: "failed", error_details: errMsg })
            .eq("id", batch[j]?.id)
        );
      }
    }
    await Promise.all(dbOps);

    // Insert chat messages for eco-retried sent items
    const ecoChatItems = [];
    for (let j = 0; j < results.length; j++) {
      const res = results[j];
      if (res.status === "fulfilled" && res.value.waMessageId) {
        ecoChatItems.push({
          phone: batch[j]?.phone || "",
          whatsapp_message_id: res.value.waMessageId,
          sent_at: new Date().toISOString(),
        });
      }
    }
    if (ecoChatItems.length > 0) {
      insertChatMessages(supabase, wa_account_id, template_name, ecoChatItems).catch(() => {});
    }

    // Log progress every 50
    const processed = Math.min(i + batch.length, recipients.length);
    if (processed % 50 < ECO_CONCURRENCY || processed === recipients.length) {
      const elapsed = ((Date.now() - functionStartTime) / 1000).toFixed(1);
      console.log(`[EcoRetry] ${processed}/${recipients.length} | sent:${sentCount} fail:${failedCount} | ${elapsed}s`);
    }

    // Delay between batches
    if (i + ECO_CONCURRENCY < recipients.length) {
      await new Promise(r => setTimeout(r, ECO_DELAY_MS));
    }
  }

  const totalTime = ((Date.now() - functionStartTime) / 1000).toFixed(1);
  console.log(`[EcoRetry] ${timedOut ? 'PARTIAL' : '✅ COMPLETE'} in ${totalTime}s | sent:${sentCount} failed:${failedCount}`);

  // Backfill any missing chat messages (safety net for fire-and-forget failures)
  if (!timedOut) {
    await backfillMissingChatMessages(supabase, wa_account_id, template_name, broadcast_id);
  }

  // Update broadcast counts
  const { data: counts } = await supabase
    .from("wa_broadcast_recipients")
    .select("status")
    .eq("broadcast_id", broadcast_id);

  if (counts) {
    const statusCounts = counts.reduce((acc: any, r: any) => {
      acc[r.status] = (acc[r.status] || 0) + 1;
      return acc;
    }, {});
    await supabase
      .from("wa_broadcasts")
      .update({
        sent_count: statusCounts.sent || 0,
        failed_count: statusCounts.failed || 0,
        delivered_count: statusCounts.delivered || 0,
        read_count: statusCounts.read || 0,
      })
      .eq("id", broadcast_id);
  }

  return { sent: sentCount, failed: failedCount, total: recipients.length, timedOut, duration: `${totalTime}s`, cached_media_id: resolvedMediaId };
}
