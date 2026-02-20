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
        result = await createTemplate(accessToken, wabaId, params.template);
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

      // ─── Send Broadcast ───────────────────────────────
      case "send_broadcast":
        result = await sendBroadcast(supabase, accessToken, phoneNumberId, params);
        break;

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
    throw new Error(data.error?.message || `Meta API error: ${response.status}`);
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
  template: any
): Promise<any> {
  if (!wabaId) throw new Error("WABA ID required to manage templates");
  if (!template) throw new Error("Missing template data");

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

// ─── Send Broadcast ──────────────────────────────────────────────
async function sendBroadcast(
  supabase: any,
  accessToken: string,
  phoneNumberId: string,
  params: any
): Promise<any> {
  const { broadcast_id, template_name, language, components, recipients } = params;

  if (!broadcast_id || !template_name || !recipients || !Array.isArray(recipients)) {
    throw new Error("Missing broadcast_id, template_name, or recipients array");
  }

  // Update broadcast status to sending
  await supabase
    .from("wa_broadcasts")
    .update({ status: "sending", sent_at: new Date().toISOString() })
    .eq("id", broadcast_id);

  let sentCount = 0;
  let failedCount = 0;

  for (const recipient of recipients) {
    const phone = recipient.phone?.replace(/^\+/, "") || "";
    if (!phone) {
      failedCount++;
      continue;
    }

    try {
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

      const result = await metaApi(accessToken, `${phoneNumberId}/messages`, "POST", payload);
      const waMessageId = result.messages?.[0]?.id;

      // Update recipient status
      if (recipient.id) {
        await supabase
          .from("wa_broadcast_recipients")
          .update({
            status: "sent",
            whatsapp_message_id: waMessageId,
            sent_at: new Date().toISOString(),
          })
          .eq("id", recipient.id);
      }
      sentCount++;

      // Rate limiting: Meta allows ~80 messages/second for business accounts
      // Add small delay to be safe
      await new Promise((r) => setTimeout(r, 50));
    } catch (err) {
      console.error(`Broadcast send failed for ${phone}:`, err);
      failedCount++;

      if (recipient.id) {
        await supabase
          .from("wa_broadcast_recipients")
          .update({
            status: "failed",
            error_message: err.message || "Send failed",
          })
          .eq("id", recipient.id);
      }
    }
  }

  // Update broadcast final status
  const finalStatus = failedCount === recipients.length ? "failed" : "completed";
  await supabase
    .from("wa_broadcasts")
    .update({
      status: finalStatus,
      total_sent: sentCount,
      total_failed: failedCount,
    })
    .eq("id", broadcast_id);

  return { sent: sentCount, failed: failedCount, total: recipients.length };
}
