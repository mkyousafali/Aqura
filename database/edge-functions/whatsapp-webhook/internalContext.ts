export type InternalIntent = {
  intent: "conversation" | "clarify" | "continue_flow" | "self_attendance" | "self_shift" | "employee_attendance" | "employee_shift" | "sales_report";
  employee_name: string;
  requested_date: string;
  reference_message_id: string;
  language: "ar" | "en";
};

export type InternalAIContext = {
  config: any;
  requester: any;
  history: any[];
  quotedMessage: any | null;
  pendingState: any | null;
  routingStatus?: string;
  decision?: InternalIntent | null;
};

function safeMessage(row: any) {
  const metadata = row.metadata || {};
  return {
    message_id: row.whatsapp_message_id || "",
    direction: row.direction,
    sent_by: row.sent_by,
    sent_at: row.created_at,
    template_name: row.template_name || null,
    content: String(row.content || "").slice(0, 2000),
    metadata: {
      source: metadata.source,
      employee_id: metadata.employee_id,
      absence_date: metadata.absence_date,
      attendance_context: metadata.attendance_context,
      reply_to_whatsapp_message_id: metadata.reply_to_whatsapp_message_id,
    },
  };
}

export async function loadInternalAIContext(
  supabase: any, conversationId: string, accountId: string, requester: any,
  inboundMessageId: string, quotedMessageId: string,
): Promise<InternalAIContext | null> {
  const [{ data: conversation, error: conversationError }, { data: settings, error: settingsError },
    { data: config, error: configError }] = await Promise.all([
    supabase.from("wa_conversations").select("id,handled_by,is_bot_handling")
      .eq("id", conversationId).eq("wa_account_id", accountId).maybeSingle(),
    supabase.from("wa_settings").select("auto_reply_enabled").eq("wa_account_id", accountId).maybeSingle(),
    supabase.from("wa_ai_bot_config").select("*").eq("wa_account_id", accountId).maybeSingle(),
  ]);
  if (conversationError || settingsError || configError) throw conversationError || settingsError || configError;
  if (!conversation || conversation.handled_by === "human" || conversation.is_bot_handling === false ||
      !settings?.auto_reply_enabled || !config?.is_enabled) return null;
  const columns = "whatsapp_message_id,direction,content,sent_by,created_at,template_name,metadata";
  const [recent, quoted, state] = await Promise.all([
    supabase.from("wa_messages").select(columns).eq("conversation_id", conversationId)
      .order("created_at", { ascending: false }).limit(24),
    quotedMessageId ? supabase.from("wa_messages").select(columns).eq("conversation_id", conversationId)
      .eq("whatsapp_message_id", quotedMessageId).maybeSingle() : Promise.resolve({ data: null, error: null }),
    supabase.from("wa_internal_assistant_state").select("pending_action,context,updated_at")
      .eq("conversation_id", conversationId).maybeSingle(),
  ]);
  if (recent.error || quoted.error || state.error) throw recent.error || quoted.error || state.error;
  const fresh = state.data && Date.now() - new Date(state.data.updated_at).getTime() < 10 * 60 * 1000;
  return {
    config, requester,
    history: [...(recent.data || [])].reverse()
      .filter(row => row.whatsapp_message_id !== inboundMessageId).map(safeMessage),
    quotedMessage: quoted.data ? safeMessage(quoted.data) : null,
    pendingState: fresh ? { pending_action: state.data.pending_action, context: {
      employee_id: state.data.context?.employee_id, query_kind: state.data.context?.query_kind,
      requested_date: state.data.context?.requested_date, date: state.data.context?.date,
      language: state.data.context?.language,
    } } : null,
  };
}

export function internalContextText(context: InternalAIContext): string {
  return JSON.stringify({
    requester: { employee_id: context.requester.employee.id, name_en: context.requester.employee.name_en,
      name_ar: context.requester.employee.name_ar },
    history_oldest_first: context.history,
    explicitly_quoted_message: context.quotedMessage,
    pending_workflow: context.pendingState,
  });
}

export function internalGuidance(config: any): string {
  return ["bot_rules", "custom_instructions", "problem_handling_info", "language_rules", "escalation_rules_instructions"]
    .filter(field => config[field]).map(field => `${field}:\n${String(config[field]).slice(0, 12000)}`).join("\n\n");
}

export function permittedReference(context: InternalAIContext, proposed: string): string {
  if (!proposed) return "";
  return [context.quotedMessage, ...context.history].some(row =>
    row?.direction === "outbound" && row.message_id === proposed) ? proposed : "";
}
