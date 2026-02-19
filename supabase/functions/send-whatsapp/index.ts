import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// WhatsApp Cloud API credentials
const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_ACCESS_TOKEN") || "";
const WHATSAPP_PHONE_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") || "";
const GRAPH_API_VERSION = "v22.0";

interface SendWhatsAppRequest {
  action: "send_access_code";
  phone_number: string; // E.164 format e.g. +966567334726
  access_code: string;
  customer_name?: string;
  language?: string; // ignored — always sends both EN and AR
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify authorization
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Supabase client for logging
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const body: SendWhatsAppRequest = await req.json();
    const { action, phone_number, access_code, customer_name } = body;

    if (action !== "send_access_code") {
      return new Response(
        JSON.stringify({ error: "Invalid action. Supported: send_access_code" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!phone_number || !access_code) {
      return new Response(
        JSON.stringify({ error: "Missing phone_number or access_code" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
      console.error("WhatsApp credentials not configured");
      return new Response(
        JSON.stringify({ error: "WhatsApp API not configured on server" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Clean phone number — remove spaces, strip + prefix for API
    const cleanPhone = phone_number.replace(/[\s\-()]/g, "");
    const formattedPhone = cleanPhone.startsWith("+") ? cleanPhone.substring(1) : cleanPhone;

    // Build template payload for a given language
    const buildPayload = (lang: string) => ({
      messaging_product: "whatsapp",
      to: formattedPhone,
      type: "template",
      template: {
        name: "aqura_access_code",
        language: { code: lang },
        components: [
          {
            type: "body",
            parameters: [{ type: "text", text: access_code }],
          },
          {
            type: "button",
            sub_type: "url",
            index: "0",
            parameters: [{ type: "text", text: access_code }],
          },
        ],
      },
    });

    // Build welcome message payload (with login button containing code in URL)
    const buildWelcomePayload = () => ({
      messaging_product: "whatsapp",
      to: formattedPhone,
      type: "template",
      template: {
        name: "aqura_welcome",
        language: { code: "en" },
        components: [
          {
            type: "button",
            sub_type: "url",
            index: "0",
            parameters: [{ type: "text", text: access_code }],
          },
        ],
      },
    });

    // Send in BOTH English and Arabic (bilingual)
    const languages = ["en", "ar"];
    let lastMessageId: string | null = null;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    for (const lang of languages) {
      console.log(`Sending WhatsApp access code to ${formattedPhone} (lang: ${lang})`);

      const waResponse = await fetch(
        `https://graph.facebook.com/${GRAPH_API_VERSION}/${WHATSAPP_PHONE_ID}/messages`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${WHATSAPP_TOKEN}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(buildPayload(lang)),
        }
      );

      const waResult = await waResponse.json();

      if (!waResponse.ok) {
        console.error(`WhatsApp API error (${lang}):`, JSON.stringify(waResult));
        continue;
      }

      console.log(`WhatsApp message sent (${lang}):`, JSON.stringify(waResult));
      lastMessageId = waResult.messages?.[0]?.id || null;

      // Log the send event
      try {
        await supabase.from("whatsapp_message_log").insert({
          phone_number: cleanPhone,
          message_type: "access_code",
          template_name: "aqura_access_code",
          template_language: lang,
          whatsapp_message_id: lastMessageId,
          status: "sent",
          customer_name: customer_name || null,
        });
      } catch (logError) {
        console.error("Failed to log WhatsApp message:", logError);
      }
    }

    // Send welcome message with login button (contains code in URL)
    try {
      console.log(`Sending welcome message with login button to ${formattedPhone}`);
      const welcomeResponse = await fetch(
        `https://graph.facebook.com/${GRAPH_API_VERSION}/${WHATSAPP_PHONE_ID}/messages`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${WHATSAPP_TOKEN}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(buildWelcomePayload()),
        }
      );

      const welcomeResult = await welcomeResponse.json();

      if (!welcomeResponse.ok) {
        console.error("Welcome message error:", JSON.stringify(welcomeResult));
      } else {
        console.log("Welcome message sent:", JSON.stringify(welcomeResult));
        const welcomeMessageId = welcomeResult.messages?.[0]?.id || null;
        // Log welcome message
        await supabase.from("whatsapp_message_log").insert({
          phone_number: cleanPhone,
          message_type: "welcome",
          template_name: "aqura_welcome",
          template_language: "en",
          whatsapp_message_id: welcomeMessageId,
          status: "sent",
          customer_name: customer_name || null,
        });
      }
    } catch (welcomeError) {
      console.error("Failed to send welcome message:", welcomeError);
    }

    if (!lastMessageId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Failed to send WhatsApp message in any language",
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message_id: lastMessageId,
        phone: cleanPhone,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error in send-whatsapp function:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
