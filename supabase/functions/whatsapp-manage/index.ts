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

      // ─── Send Broadcast (fire-and-forget) ──────────────
      // Returns immediately, processes in background to avoid Kong 504 timeout
      case "send_broadcast": {
        // Start broadcast in background — do NOT await
        sendBroadcast(supabase, accessToken, phoneNumberId, params).catch((err) => {
          console.error("[Broadcast] Background processing error:", err);
        });
        // Return immediately so the frontend doesn't timeout
        return new Response(
          JSON.stringify({ success: true, data: { status: "processing", message: "Broadcast started, processing in background" } }),
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

      if ((isRateLimit || isTransient) && attempt < maxRetries) {
        // Exponential backoff: 2s, 4s, 8s
        const delay = Math.pow(2, attempt + 1) * 1000;
        console.log(`[Broadcast] Rate limited, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
        await new Promise((r) => setTimeout(r, delay));
        continue;
      }
      throw err; // Not retryable or max retries reached
    }
  }
}

// ─── Send Broadcast ──────────────────────────────────────────────
async function sendBroadcast(
  supabase: any,
  accessToken: string,
  phoneNumberId: string,
  params: any
): Promise<any> {
  const { broadcast_id, template_name, language, components } = params;
  let { recipients } = params;

  if (!broadcast_id || !template_name) {
    throw new Error("Missing broadcast_id or template_name");
  }

  // If recipients not passed (large broadcast), read them from DB directly
  // This avoids sending a huge request body for 20k+ recipients
  if (!recipients || !Array.isArray(recipients) || recipients.length === 0) {
    console.log(`[Broadcast] No recipients in request body, reading from DB...`);
    const { data: dbRecipients, error: dbErr } = await supabase
      .from("wa_broadcast_recipients")
      .select("id, phone_number")
      .eq("broadcast_id", broadcast_id)
      .eq("status", "pending");
    
    if (dbErr) throw new Error("Failed to load recipients: " + dbErr.message);
    recipients = (dbRecipients || []).map((r: any) => ({ id: r.id, phone: r.phone_number }));
    console.log(`[Broadcast] Loaded ${recipients.length} pending recipients from DB`);
  }

  console.log(`[Broadcast] Starting: template=${template_name}, lang=${language}, recipients=${recipients?.length}, hasComponents=${!!components}`);
  if (components) console.log(`[Broadcast] Components:`, JSON.stringify(components));

  // ─── Filter out unsubscribed customers (is_deleted = true) ───
  const allPhones = recipients.map((r: any) => (r.phone || "").replace(/^\+/, "").replace(/\D/g, "")).filter(Boolean);
  const allPhonesWithPlus = allPhones.map((p: string) => `+${p}`);
  const phoneLookup = [...allPhones, ...allPhonesWithPlus];

  let unsubscribedPhones = new Set<string>();
  if (phoneLookup.length > 0) {
    // Batch the unsubscribe lookup in chunks to avoid URL length issues
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

  const filteredRecipients = recipients.filter((r: any) => {
    const clean = (r.phone || "").replace(/^\+/, "").replace(/\D/g, "");
    return !unsubscribedPhones.has(clean);
  });

  const skippedCount = recipients.length - filteredRecipients.length;
  if (skippedCount > 0) {
    console.log(`[Broadcast] Skipped ${skippedCount} unsubscribed recipients out of ${recipients.length} total`);
  }

  // Update broadcast status to sending
  await supabase
    .from("wa_broadcasts")
    .update({ status: "sending" })
    .eq("id", broadcast_id);

  let sentCount = 0;
  let failedCount = 0;
  let rateLimitHits = 0;

  // ─── Adaptive high-performance parallel sending ───
  // Meta allows ~80 messages/second for business accounts.
  // Start with 40 concurrent (safe), auto-reduce if rate limited.
  let concurrency = 40;
  const DB_BATCH_SIZE = 200;
  const startTime = Date.now();

  // Accumulate DB updates and flush in batches
  const sentUpdates: { id: string; whatsapp_message_id: string; sent_at: string }[] = [];
  const failedUpdates: { id: string; error_details: string }[] = [];

  async function flushSentUpdates() {
    if (sentUpdates.length === 0) return;
    const batch = sentUpdates.splice(0, sentUpdates.length);
    const chunks = [];
    for (let i = 0; i < batch.length; i += 50) {
      chunks.push(batch.slice(i, i + 50));
    }
    await Promise.all(chunks.map(async (chunk) => {
      for (const item of chunk) {
        await supabase
          .from("wa_broadcast_recipients")
          .update({
            status: "sent",
            whatsapp_message_id: item.whatsapp_message_id,
            sent_at: item.sent_at,
          })
          .eq("id", item.id);
      }
    }));
  }

  async function flushFailedUpdates() {
    if (failedUpdates.length === 0) return;
    const batch = failedUpdates.splice(0, failedUpdates.length);
    const chunks = [];
    for (let i = 0; i < batch.length; i += 50) {
      chunks.push(batch.slice(i, i + 50));
    }
    await Promise.all(chunks.map(async (chunk) => {
      for (const item of chunk) {
        await supabase
          .from("wa_broadcast_recipients")
          .update({
            status: "failed",
            error_details: item.error_details,
          })
          .eq("id", item.id);
      }
    }));
  }

  // Process recipients in concurrent batches with adaptive speed
  for (let i = 0; i < filteredRecipients.length; i += concurrency) {
    const batch = filteredRecipients.slice(i, i + concurrency);
    let batchRateLimited = 0;

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
            ...(components ? { components } : {}),
          },
        };

        // Use retry wrapper — auto-retries on rate limit with backoff
        const result = await sendWithRetry(accessToken, phoneNumberId, payload);
        return { recipient, waMessageId: result.messages?.[0]?.id };
      })
    );

    // Collect results
    const now = new Date().toISOString();
    for (let j = 0; j < results.length; j++) {
      const res = results[j];
      if (res.status === "fulfilled") {
        sentCount++;
        if (res.value.recipient.id) {
          sentUpdates.push({
            id: res.value.recipient.id,
            whatsapp_message_id: res.value.waMessageId || "",
            sent_at: now,
          });
        }
      } else {
        const errMsg = res.reason?.message || "Send failed";
        const isRateLimit = errMsg.includes("130429") || errMsg.includes("rate") || errMsg.includes("throttl");
        if (isRateLimit) {
          batchRateLimited++;
          rateLimitHits++;
        }
        failedCount++;
        const recipient = batch[j];
        console.error(`Broadcast send failed for ${recipient?.phone}:`, errMsg.substring(0, 200));
        if (recipient?.id) {
          failedUpdates.push({
            id: recipient.id,
            error_details: errMsg.substring(0, 1000),
          });
        }
      }
    }

    // ─── Adaptive concurrency ───
    // If we got rate limited in this batch, reduce concurrency and add longer delay
    if (batchRateLimited > 0) {
      const oldConcurrency = concurrency;
      concurrency = Math.max(10, Math.floor(concurrency * 0.6)); // Reduce by 40%
      console.log(`[Broadcast] Rate limited ${batchRateLimited}x in batch, reducing concurrency ${oldConcurrency} → ${concurrency}`);
      await new Promise((r) => setTimeout(r, 5000)); // 5s cooldown
    } else if (rateLimitHits === 0 && concurrency < 40) {
      // Gradually recover concurrency if no rate limits
      concurrency = Math.min(40, concurrency + 5);
    }

    // Flush DB updates periodically
    if (sentUpdates.length >= DB_BATCH_SIZE) await flushSentUpdates();
    if (failedUpdates.length >= DB_BATCH_SIZE) await flushFailedUpdates();

    // Log progress every 500 messages
    const processed = Math.min(i + batch.length, filteredRecipients.length);
    if (processed % 500 < concurrency || processed === filteredRecipients.length) {
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
      const rate = (sentCount / (Date.now() - startTime) * 1000).toFixed(1);
      const eta = sentCount > 0 ? (((filteredRecipients.length - processed) / (sentCount / ((Date.now() - startTime) / 1000))) ).toFixed(0) : '?';
      console.log(`[Broadcast] ${processed}/${filteredRecipients.length} | sent:${sentCount} failed:${failedCount} | ${elapsed}s elapsed | ${rate} msg/s | ETA: ${eta}s | concurrency:${concurrency}`);
    }

    // Delay between batches — 200ms keeps us safely under 80 msg/s
    if (i + concurrency < filteredRecipients.length) {
      await new Promise((r) => setTimeout(r, 200));
    }
  }

  // Flush remaining DB updates
  await Promise.all([flushSentUpdates(), flushFailedUpdates()]);

  const totalTime = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`[Broadcast] COMPLETE in ${totalTime}s | sent:${sentCount} failed:${failedCount} skipped:${skippedCount} rateLimitHits:${rateLimitHits}`);

  // Update broadcast final status
  const finalStatus = failedCount === filteredRecipients.length ? "failed" : "completed";
  await supabase
    .from("wa_broadcasts")
    .update({
      status: finalStatus,
      sent_count: sentCount,
      failed_count: failedCount + skippedCount,
      completed_at: new Date().toISOString(),
    })
    .eq("id", broadcast_id);

  return { sent: sentCount, failed: failedCount, skipped: skippedCount, rateLimitHits, total: recipients.length, duration: `${totalTime}s` };
}
