import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const VERIFY_TOKEN = Deno.env.get("WHATSAPP_WEBHOOK_VERIFY_TOKEN") || "aqura_wa_verify_2024";
const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_ACCESS_TOKEN") || "";
const WHATSAPP_PHONE_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") || "";
const GRAPH_API_VERSION = "v22.0";

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // ─── GET: Meta Webhook Verification ────────────────────────────
  if (req.method === "GET") {
    const url = new URL(req.url);
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");

    if (mode === "subscribe" && token === VERIFY_TOKEN) {
      console.log("Webhook verified successfully");
      return new Response(challenge, { status: 200, headers: corsHeaders });
    }

    return new Response("Forbidden", { status: 403, headers: corsHeaders });
  }

  // ─── POST: Incoming Messages & Status Updates ──────────────────
  if (req.method === "POST") {
    try {
      const body = await req.json();

      // Meta sends webhooks under object "whatsapp_business_account"
      if (body.object !== "whatsapp_business_account") {
        return new Response("OK", { status: 200, headers: corsHeaders });
      }

      const entries = body.entry || [];
      for (const entry of entries) {
        const changes = entry.changes || [];
        for (const change of changes) {
          if (change.field !== "messages") continue;

          const value = change.value;
          const metadata = value.metadata || {};
          const phoneNumberId = metadata.phone_number_id;

          // ─── Handle Status Updates ───────────────────────
          const statuses = value.statuses || [];
          for (const status of statuses) {
            await handleStatusUpdate(supabase, status, phoneNumberId);
          }

          // ─── Handle Incoming Messages ────────────────────
          const messages = value.messages || [];
          const contacts = value.contacts || [];
          for (const message of messages) {
            const contact = contacts.find((c: any) => c.wa_id === message.from) || {};
            await handleIncomingMessage(supabase, message, contact, phoneNumberId);
          }
        }
      }

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (error) {
      console.error("Webhook processing error:", error);
      // Always return 200 to Meta to avoid retries
      return new Response(JSON.stringify({ error: "Processing error" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  return new Response("Method not allowed", { status: 405, headers: corsHeaders });
});

// ─── Handle Status Updates (sent → delivered → read → failed) ──────
async function handleStatusUpdate(supabase: any, status: any, phoneNumberId: string) {
  try {
    const { id, status: msgStatus, timestamp, errors } = status;

    // Update message status
    const { error } = await supabase
      .from("wa_messages")
      .update({
        status: msgStatus,
        ...(msgStatus === "delivered" ? { delivered_at: new Date(parseInt(timestamp) * 1000).toISOString() } : {}),
        ...(msgStatus === "read" ? { read_at: new Date(parseInt(timestamp) * 1000).toISOString() } : {}),
        ...(msgStatus === "failed" ? { error_message: errors?.[0]?.title || "Unknown error" } : {}),
      })
      .eq("whatsapp_message_id", id);

    if (error) console.error("Failed to update message status:", error);
  } catch (err) {
    console.error("handleStatusUpdate error:", err);
  }
}

// ─── Handle Incoming Message ───────────────────────────────────────
async function handleIncomingMessage(
  supabase: any,
  message: any,
  contact: any,
  phoneNumberId: string
) {
  try {
    const senderPhone = message.from; // e.g. "966567334726"
    const senderName = contact.profile?.name || senderPhone;
    const messageId = message.id;
    const timestamp = message.timestamp;

    // ─── Resolve WhatsApp Account ───────────────────
    const { data: waAccount } = await supabase
      .from("wa_accounts")
      .select("id, branch_id")
      .eq("phone_number_id", phoneNumberId)
      .eq("is_active", true)
      .single();

    const accountId = waAccount?.id || null;
    const branchId = waAccount?.branch_id || null;

    // ─── Find or Create Conversation ────────────────
    let conversationId: string;

    const { data: existingConv } = await supabase
      .from("wa_conversations")
      .select("id, last_message_at, window_expires_at")
      .eq("customer_phone", senderPhone)
      .eq("account_id", accountId)
      .eq("status", "open")
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    if (existingConv) {
      conversationId = existingConv.id;
      // Update conversation
      await supabase
        .from("wa_conversations")
        .update({
          last_message_at: new Date(parseInt(timestamp) * 1000).toISOString(),
          unread_count: supabase.rpc ? undefined : 0, // will increment below
          window_expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
          customer_name: senderName,
        })
        .eq("id", conversationId);

      // Increment unread count
      await supabase.rpc("increment_field", {
        table_name: "wa_conversations",
        field_name: "unread_count",
        row_id: conversationId,
        increment_by: 1,
      }).catch(() => {
        // Fallback: just update
        supabase
          .from("wa_conversations")
          .update({ unread_count: (existingConv as any).unread_count + 1 })
          .eq("id", conversationId);
      });
    } else {
      // Create new conversation
      const { data: newConv, error: convError } = await supabase
        .from("wa_conversations")
        .insert({
          account_id: accountId,
          branch_id: branchId,
          customer_phone: senderPhone,
          customer_name: senderName,
          status: "open",
          handled_by: "bot",
          last_message_at: new Date(parseInt(timestamp) * 1000).toISOString(),
          window_expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
          unread_count: 1,
        })
        .select("id")
        .single();

      if (convError) {
        console.error("Failed to create conversation:", convError);
        return;
      }
      conversationId = newConv.id;
    }

    // ─── Extract Message Content ────────────────────
    let content = "";
    let messageType = message.type || "text";
    let mediaUrl: string | null = null;

    switch (messageType) {
      case "text":
        content = message.text?.body || "";
        break;
      case "image":
        content = message.image?.caption || "[Image]";
        mediaUrl = await getMediaUrl(message.image?.id);
        break;
      case "video":
        content = message.video?.caption || "[Video]";
        mediaUrl = await getMediaUrl(message.video?.id);
        break;
      case "audio":
        content = "[Audio]";
        mediaUrl = await getMediaUrl(message.audio?.id);
        break;
      case "document":
        content = message.document?.caption || message.document?.filename || "[Document]";
        mediaUrl = await getMediaUrl(message.document?.id);
        break;
      case "location":
        content = `[Location: ${message.location?.latitude}, ${message.location?.longitude}]`;
        break;
      case "contacts":
        content = `[Contact: ${message.contacts?.[0]?.name?.formatted_name || "Unknown"}]`;
        break;
      case "sticker":
        content = "[Sticker]";
        mediaUrl = await getMediaUrl(message.sticker?.id);
        break;
      case "interactive":
        // Button reply or list reply
        if (message.interactive?.type === "button_reply") {
          content = message.interactive.button_reply?.title || "[Button Reply]";
        } else if (message.interactive?.type === "list_reply") {
          content = message.interactive.list_reply?.title || "[List Reply]";
        }
        messageType = "text"; // normalize
        break;
      case "reaction":
        content = message.reaction?.emoji || "[Reaction]";
        break;
      default:
        content = `[${messageType}]`;
    }

    // ─── Save Message ───────────────────────────────
    const { error: msgError } = await supabase.from("wa_messages").insert({
      conversation_id: conversationId,
      whatsapp_message_id: messageId,
      direction: "inbound",
      message_type: messageType,
      content,
      media_url: mediaUrl,
      status: "received",
      sent_by: "customer",
      created_at: new Date(parseInt(timestamp) * 1000).toISOString(),
    });

    if (msgError) {
      console.error("Failed to save message:", msgError);
      return;
    }

    // ─── Trigger Auto-Reply Bot ─────────────────────
    if (messageType === "text" && content) {
      await tryAutoReply(supabase, conversationId, accountId, branchId, senderPhone, content);
    }

    // ─── Trigger AI Bot (if no auto-reply matched) ──
    // The auto-reply function will set a flag if it handled the message
    // AI bot checks that flag and only responds if no auto-reply was sent

  } catch (err) {
    console.error("handleIncomingMessage error:", err);
  }
}

// ─── Get Media URL from WhatsApp ───────────────────────────────────
async function getMediaUrl(mediaId: string | undefined): Promise<string | null> {
  if (!mediaId || !WHATSAPP_TOKEN) return null;
  try {
    const res = await fetch(`https://graph.facebook.com/${GRAPH_API_VERSION}/${mediaId}`, {
      headers: { Authorization: `Bearer ${WHATSAPP_TOKEN}` },
    });
    const data = await res.json();
    return data.url || null;
  } catch {
    return null;
  }
}

// ─── Auto-Reply Bot Logic ──────────────────────────────────────────
async function tryAutoReply(
  supabase: any,
  conversationId: string,
  accountId: string | null,
  branchId: string | null,
  senderPhone: string,
  messageText: string
) {
  try {
    // Check if conversation is handled by human — skip bot
    const { data: conv } = await supabase
      .from("wa_conversations")
      .select("handled_by")
      .eq("id", conversationId)
      .single();

    if (conv?.handled_by === "human") return;

    // Get active auto-reply triggers
    const { data: triggers } = await supabase
      .from("wa_auto_reply_triggers")
      .select("*")
      .eq("is_active", true)
      .or(accountId ? `account_id.eq.${accountId},account_id.is.null` : "account_id.is.null")
      .order("priority", { ascending: true });

    if (!triggers || triggers.length === 0) {
      // No auto-reply triggers — try AI bot
      await tryAIReply(supabase, conversationId, accountId, branchId, senderPhone, messageText);
      return;
    }

    const lowerText = messageText.toLowerCase().trim();

    for (const trigger of triggers) {
      const keywordsEn: string[] = trigger.keywords_en || [];
      const keywordsAr: string[] = trigger.keywords_ar || [];
      const allKeywords = [...keywordsEn, ...keywordsAr].map((k) => k.toLowerCase());
      const matchType = trigger.match_type || "contains";

      let matched = false;

      for (const keyword of allKeywords) {
        switch (matchType) {
          case "exact":
            matched = lowerText === keyword;
            break;
          case "starts_with":
            matched = lowerText.startsWith(keyword);
            break;
          case "regex":
            try {
              matched = new RegExp(keyword, "i").test(messageText);
            } catch {
              matched = false;
            }
            break;
          case "contains":
          default:
            matched = lowerText.includes(keyword);
            break;
        }
        if (matched) break;
      }

      if (!matched) continue;

      // ─── Send Auto-Reply ──────────────────────────
      const response = trigger.response || {};
      let replySent = false;

      if (response.type === "text" && response.text) {
        replySent = await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
          type: "text",
          text: { body: response.text },
        }, "auto_reply");
      } else if (response.type === "image" && response.image_url) {
        replySent = await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
          type: "image",
          image: { link: response.image_url, caption: response.caption || "" },
        }, "auto_reply");
      } else if (response.type === "document" && response.document_url) {
        replySent = await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
          type: "document",
          document: { link: response.document_url, caption: response.caption || "", filename: response.filename || "document" },
        }, "auto_reply");
      } else if (response.type === "template" && response.template_name) {
        replySent = await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
          type: "template",
          template: {
            name: response.template_name,
            language: { code: response.template_language || "en" },
          },
        }, "auto_reply");
      } else if (response.type === "interactive" && response.buttons) {
        replySent = await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
          type: "interactive",
          interactive: {
            type: "button",
            body: { text: response.text || "Choose an option" },
            action: {
              buttons: response.buttons.slice(0, 3).map((btn: any, i: number) => ({
                type: "reply",
                reply: { id: `btn_${i}`, title: btn.title || `Option ${i + 1}` },
              })),
            },
          },
        }, "auto_reply");
      }

      if (replySent) {
        // Update conversation as handled by auto-reply bot
        await supabase
          .from("wa_conversations")
          .update({ handled_by: "auto_reply" })
          .eq("id", conversationId);

        // Send follow-up if configured
        if (trigger.follow_up_message && trigger.follow_up_delay_seconds) {
          setTimeout(async () => {
            await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
              type: "text",
              text: { body: trigger.follow_up_message },
            }, "auto_reply");
          }, trigger.follow_up_delay_seconds * 1000);
        }

        return; // Stop after first match
      }
    }

    // No trigger matched — try AI bot
    await tryAIReply(supabase, conversationId, accountId, branchId, senderPhone, messageText);
  } catch (err) {
    console.error("tryAutoReply error:", err);
  }
}

// ─── AI Bot Reply Logic ────────────────────────────────────────────
async function tryAIReply(
  supabase: any,
  conversationId: string,
  accountId: string | null,
  branchId: string | null,
  senderPhone: string,
  messageText: string
) {
  try {
    const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
    if (!OPENAI_API_KEY) return;

    // Get AI bot config
    const query = supabase
      .from("wa_ai_bot_config")
      .select("*")
      .eq("is_active", true);

    if (accountId) {
      query.or(`account_id.eq.${accountId},account_id.is.null`);
    }

    const { data: configs } = await query.order("created_at", { ascending: false }).limit(1);
    const config = configs?.[0];

    if (!config) return;

    // Check handoff keywords
    const handoffKeywords: string[] = config.handoff_keywords || [];
    const lowerText = messageText.toLowerCase();
    for (const keyword of handoffKeywords) {
      if (lowerText.includes(keyword.toLowerCase())) {
        // Handoff to human
        await supabase
          .from("wa_conversations")
          .update({ handled_by: "human" })
          .eq("id", conversationId);

        await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
          type: "text",
          text: { body: config.handoff_message || "You are being connected to a human agent. Please wait..." },
        }, "ai_bot");
        return;
      }
    }

    // Check message count for auto-handoff
    const { count: msgCount } = await supabase
      .from("wa_messages")
      .select("id", { count: "exact", head: true })
      .eq("conversation_id", conversationId)
      .eq("direction", "inbound");

    if (config.max_messages_before_handoff && msgCount && msgCount >= config.max_messages_before_handoff) {
      await supabase
        .from("wa_conversations")
        .update({ handled_by: "human" })
        .eq("id", conversationId);

      await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
        type: "text",
        text: { body: config.handoff_message || "Connecting you to a team member..." },
      }, "ai_bot");
      return;
    }

    // Get conversation history for context (last 10 messages)
    const { data: history } = await supabase
      .from("wa_messages")
      .select("direction, content, sent_by")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true })
      .limit(10);

    // Build training context from Q&A pairs
    const { data: trainingData } = await supabase
      .from("wa_ai_bot_config")
      .select("training_data")
      .eq("id", config.id)
      .single();

    let trainingContext = "";
    if (trainingData?.training_data && Array.isArray(trainingData.training_data)) {
      trainingContext = "\n\nTraining Q&A:\n" +
        trainingData.training_data
          .map((item: any) => `Q: ${item.question}\nA: ${item.answer}`)
          .join("\n\n");
    }

    // Build system prompt
    const systemPrompt = (config.system_prompt || "You are a helpful business assistant.") +
      `\nTone: ${config.tone || "professional"}` +
      `\nLanguage: ${config.response_language || "auto-detect from user message"}` +
      trainingContext;

    // Build messages array
    const openaiMessages: any[] = [
      { role: "system", content: systemPrompt },
    ];

    if (history) {
      for (const msg of history) {
        openaiMessages.push({
          role: msg.direction === "inbound" ? "user" : "assistant",
          content: msg.content,
        });
      }
    }

    // Add current message
    openaiMessages.push({ role: "user", content: messageText });

    // Call OpenAI
    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: config.model || "gpt-4o-mini",
        messages: openaiMessages,
        max_tokens: config.max_tokens || 500,
        temperature: config.temperature || 0.7,
      }),
    });

    const openaiResult = await openaiResponse.json();

    if (!openaiResponse.ok) {
      console.error("OpenAI API error:", JSON.stringify(openaiResult));
      return;
    }

    const aiReply = openaiResult.choices?.[0]?.message?.content;
    if (!aiReply) return;

    // Send AI reply
    await sendWhatsAppMessage(supabase, conversationId, senderPhone, {
      type: "text",
      text: { body: aiReply },
    }, "ai_bot");

    // Update conversation handler
    await supabase
      .from("wa_conversations")
      .update({ handled_by: "ai_bot" })
      .eq("id", conversationId);

    // Log AI interaction
    console.log(`AI Bot replied to ${senderPhone} in conversation ${conversationId}`);

  } catch (err) {
    console.error("tryAIReply error:", err);
  }
}

// ─── Send WhatsApp Message via Cloud API ───────────────────────────
async function sendWhatsAppMessage(
  supabase: any,
  conversationId: string,
  recipientPhone: string,
  messagePayload: any,
  sentBy: string
): Promise<boolean> {
  try {
    if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
      console.error("WhatsApp credentials not configured");
      return false;
    }

    const formattedPhone = recipientPhone.startsWith("+")
      ? recipientPhone.substring(1)
      : recipientPhone;

    const payload = {
      messaging_product: "whatsapp",
      to: formattedPhone,
      ...messagePayload,
    };

    const response = await fetch(
      `https://graph.facebook.com/${GRAPH_API_VERSION}/${WHATSAPP_PHONE_ID}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${WHATSAPP_TOKEN}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      }
    );

    const result = await response.json();

    if (!response.ok) {
      console.error("WhatsApp send error:", JSON.stringify(result));
      return false;
    }

    const waMessageId = result.messages?.[0]?.id || null;

    // Save outbound message
    const content = messagePayload.text?.body ||
      messagePayload.template?.name ||
      messagePayload.interactive?.body?.text ||
      `[${messagePayload.type}]`;

    await supabase.from("wa_messages").insert({
      conversation_id: conversationId,
      whatsapp_message_id: waMessageId,
      direction: "outbound",
      message_type: messagePayload.type || "text",
      content,
      status: "sent",
      sent_by: sentBy,
    });

    // Update conversation last_message_at
    await supabase
      .from("wa_conversations")
      .update({ last_message_at: new Date().toISOString() })
      .eq("id", conversationId);

    return true;
  } catch (err) {
    console.error("sendWhatsAppMessage error:", err);
    return false;
  }
}
