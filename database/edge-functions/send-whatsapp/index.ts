import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const GRAPH_API_VERSION = "v22.0";

// Load WhatsApp credentials from wa_accounts table (default active account)
async function getWaCredentials(supabase: any): Promise<{ token: string; phoneId: string }> {
  const { data } = await supabase
    .from("wa_accounts")
    .select("access_token, phone_number_id")
    .eq("is_active", true)
    .eq("is_default", true)
    .maybeSingle();
  return { token: data?.access_token || "", phoneId: data?.phone_number_id || "" };
}

interface SendWhatsAppRequest {
  action: "send_access_code" | "send_loyalty_otp" | "send_customer_auth_otp";
  phone_number: string; // E.164 format e.g. +966567334726
  access_code?: string;
  customer_name?: string;
  purpose?: "registration" | "login";
  language?: string;
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
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const { token: WHATSAPP_TOKEN, phoneId: WHATSAPP_PHONE_ID } = await getWaCredentials(supabase);

    const body: SendWhatsAppRequest = await req.json();
    const { action, phone_number, customer_name, purpose, language } = body;
    let access_code = body.access_code;
    let customerOtpExpirySeconds: number | undefined;

    if (action !== "send_access_code" && action !== "send_loyalty_otp" && action !== "send_customer_auth_otp") {
      return new Response(
        JSON.stringify({ error: "Invalid action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!phone_number || (action !== "send_customer_auth_otp" && !access_code)) {
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

    // Customer authentication OTPs are issued only on the server. The plaintext
    // OTP is used for this WhatsApp request and is never returned to the browser.
    if (action === "send_customer_auth_otp") {
      if (purpose !== "registration" && purpose !== "login") {
        return new Response(
          JSON.stringify({ success: false, error: "Invalid OTP purpose" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const { data: issueResult, error: issueError } = await supabase.rpc("issue_customer_auth_otp", {
        p_whatsapp_number: cleanPhone,
        p_purpose: purpose,
        p_customer_name: customer_name || null,
      });
      if (issueError || !issueResult?.success) {
        return new Response(
          JSON.stringify(issueResult || { success: false, error: issueError?.message || "Unable to issue OTP" }),
          { status: issueResult?.error === "locked" ? 429 : 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      access_code = issueResult.otp;
      customerOtpExpirySeconds = issueResult.expires_in_seconds;
    }

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

    // Loyalty OTP — uses Authentication template "loyalty_redemption_otp" (Copy code, Arabic)
    if (action === "send_loyalty_otp" || action === "send_customer_auth_otp") {
      const otpTemplateName = action === "send_customer_auth_otp" ? "aqura_otp_verification" : "loyalty_redemption_otp";
      const otpLanguage = action === "send_customer_auth_otp" && language === "en" ? "en" : "ar";
      const loyaltyPayload = {
        messaging_product: "whatsapp",
        to: formattedPhone,
        type: "template",
        template: {
          name: otpTemplateName,
          language: { code: otpLanguage },
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
      };

      console.log(`Sending ${action === "send_customer_auth_otp" ? "customer auth" : "loyalty"} OTP to ${formattedPhone}`);

      const waResponse = await fetch(
        `https://graph.facebook.com/${GRAPH_API_VERSION}/${WHATSAPP_PHONE_ID}/messages`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${WHATSAPP_TOKEN}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(loyaltyPayload),
        }
      );

      const waResult = await waResponse.json();
      const loyaltyMessageId = waResult.messages?.[0]?.id || null;

      if (!waResponse.ok) {
        console.error("WhatsApp loyalty OTP error:", JSON.stringify(waResult));
        return new Response(
          JSON.stringify({ success: false, error: "WhatsApp OTP delivery failed" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } else {
        console.log("Loyalty OTP sent:", JSON.stringify(waResult));
        try {
          await supabase.from("whatsapp_message_log").insert({
            phone_number: cleanPhone,
            message_type: action === "send_customer_auth_otp" ? "customer_auth_otp" : "loyalty_otp",
            template_name: otpTemplateName,
            template_language: otpLanguage,
            whatsapp_message_id: loyaltyMessageId,
            status: "sent",
            customer_name: customer_name || null,
          });
        } catch (logError) {
          console.error("Failed to log loyalty OTP message:", logError);
        }
      }

      // Customer authentication is always bilingual: send the same one-time
      // code in the other approved template language as a second message.
      if (action === "send_customer_auth_otp") {
        const secondLanguage = otpLanguage === "en" ? "ar" : "en";
        const secondPayload = {
          ...loyaltyPayload,
          template: { ...loyaltyPayload.template, language: { code: secondLanguage } },
        };
        const secondResponse = await fetch(
          `https://graph.facebook.com/${GRAPH_API_VERSION}/${WHATSAPP_PHONE_ID}/messages`,
          {
            method: "POST",
            headers: { Authorization: `Bearer ${WHATSAPP_TOKEN}`, "Content-Type": "application/json" },
            body: JSON.stringify(secondPayload),
          }
        );
        const secondResult = await secondResponse.json();
        if (!secondResponse.ok) {
          console.error(`WhatsApp customer OTP error (${secondLanguage}):`, JSON.stringify(secondResult));
          return new Response(
            JSON.stringify({ success: false, error: `WhatsApp OTP delivery failed (${secondLanguage})` }),
            { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
        const secondMessageId = secondResult.messages?.[0]?.id || null;
        try {
          await supabase.from("whatsapp_message_log").insert({
            phone_number: cleanPhone,
            message_type: "customer_auth_otp",
            template_name: otpTemplateName,
            template_language: secondLanguage,
            whatsapp_message_id: secondMessageId,
            status: "sent",
            customer_name: customer_name || null,
          });
        } catch (logError) {
          console.error("Failed to log bilingual customer OTP message:", logError);
        }
      }

      return new Response(
        JSON.stringify({ success: true, message_id: loyaltyMessageId, phone: cleanPhone, expires_in_seconds: customerOtpExpirySeconds }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Send in BOTH English and Arabic (bilingual)
    const languages = ["en", "ar"];
    let lastMessageId: string | null = null;

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
