export type AttendanceReplyContext = { employeeId: string; shiftDate: string };

function validContext(value: any): AttendanceReplyContext | null {
  if (typeof value?.employee_id !== "string" || !value.employee_id.trim() ||
      !/^\d{4}-\d{2}-\d{2}$/.test(value?.shift_date || "")) return null;
  const date = new Date(`${value.shift_date}T12:00:00Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value.shift_date) return null;
  return { employeeId: value.employee_id, shiftDate: value.shift_date };
}

export function resolveAttendanceReplyDate(
  requestedDate: string, content: string, originalDate: string, today: string,
): string | null {
  let requested = requestedDate;
  if (requested === "unspecified") {
    if (/\byesterday\b/i.test(content) || /أمس|امس/.test(content)) requested = "yesterday";
    else if (/\btomorrow\b/i.test(content) || /غدا|غداً|بكرة/.test(content)) requested = "tomorrow";
    else if (/\btoday\b/i.test(content) || /اليوم/.test(content)) requested = "today";
    else {
      const normalized = content.replace(/[٠-٩۰-۹]/g, digit =>
        String("٠١٢٣٤٥٦٧٨٩".indexOf(digit) >= 0 ? "٠١٢٣٤٥٦٧٨٩".indexOf(digit) : "۰۱۲۳۴۵۶۷۸۹".indexOf(digit)));
      requested = normalized.match(/\b(?:\d{4}[-\/]\d{1,2}[-\/]\d{1,2}|\d{1,2}[-\/]\d{1,2}[-\/]\d{4})\b/)?.[0] || originalDate;
    }
  }
  if (["today", "yesterday", "tomorrow"].includes(requested)) {
    const date = new Date(`${today}T12:00:00Z`);
    date.setUTCDate(date.getUTCDate() + (requested === "yesterday" ? -1 : requested === "tomorrow" ? 1 : 0));
    return date.toISOString().slice(0, 10);
  }
  const ymd = requested.match(/^(\d{4})[-\/](\d{1,2})[-\/](\d{1,2})$/);
  const dmy = requested.match(/^(\d{1,2})[-\/](\d{1,2})[-\/](\d{4})$/);
  const parts = ymd ? [ymd[1], ymd[2], ymd[3]] : dmy ? [dmy[3], dmy[2], dmy[1]] : null;
  if (!parts) return null;
  return validContext({ employee_id: "date-validation", shift_date:
    `${parts[0]}-${parts[1].padStart(2, "0")}-${parts[2].padStart(2, "0")}` })?.shiftDate || null;
}

export async function resolveQuotedAttendance(
  supabase: any, conversationId: string, quotedMessageId: string,
): Promise<AttendanceReplyContext | null> {
  // Never resolve another conversation/account's message, an inbound message,
  // or an employee name guessed from the quoted bubble's text.
  const { data: message, error } = await supabase.from("wa_messages")
    .select("metadata").eq("conversation_id", conversationId)
    .eq("whatsapp_message_id", quotedMessageId).eq("direction", "outbound").maybeSingle();
  if (error) throw error;
  if (!message) return null;
  const stored = validContext(message.metadata?.attendance_context);
  if (stored) return stored;
  if (message.metadata?.source === "attendance_absence_reminder") {
    const absence = validContext({ employee_id: message.metadata.employee_id, shift_date: message.metadata.absence_date });
    if (absence) return absence;
  }

  // Existing automated alerts have a provider ID linked to their source
  // delivery. This works for already-sent alerts without a migration/backfill.
  const { data: delivery, error: deliveryError } = await supabase.from("attendance_no_show_deliveries")
    .select("attendance_no_show_alerts!inner(employee_id,shift_date)")
    .eq("provider_message_id", quotedMessageId).eq("channel", "whatsapp").maybeSingle();
  if (deliveryError) throw deliveryError;
  return validContext(delivery?.attendance_no_show_alerts);
}

type ReplyRequest = {
  conversationId: string;
  quotedMessageId: string;
  content: string;
  semanticIntent: { intent: string; employee_name: string; requested_date: string } | null;
};

type ReplyServices = {
  getPermitted: () => Promise<any>;
  nameMatches: (name: string, employee: any) => boolean;
  resolveDate: (requestedDate: string, content: string, originalDate: string) => string | null;
  clearState: () => Promise<void>;
  report: (employee: any, date: string, queryKind: string) => Promise<void>;
  denied: () => Promise<void>;
  failed: (error: unknown) => Promise<void>;
};

export async function handleQuotedAttendanceReply(
  supabase: any, request: ReplyRequest, services: ReplyServices,
): Promise<boolean> {
  const semantic = request.semanticIntent;
  if (!request.quotedMessageId ||
      (semantic && !["employee_attendance", "employee_shift"].includes(semantic.intent)) ||
      !semantic) return false;
  try {
    const context = await resolveQuotedAttendance(supabase, request.conversationId, request.quotedMessageId);
    if (!context) return false;
    // Recheck current employee/branch permissions even for a genuine old alert.
    const permitted = await services.getPermitted();
    const employee = permitted?.employees.find((row: any) => String(row.id) === context.employeeId);
    if (!employee) {
      await services.denied();
      return true;
    }
    // A new explicitly named employee must use the ordinary secured lookup,
    // not silently get replaced by the employee in the quoted notification.
    const writtenName = semantic?.employee_name?.trim() || "";
    const pronoun = /^(he|she|him|her|they|them|the employee|this employee|employee|هو|هي|الموظف|الموظفة|هذا الموظف|هذه الموظفة)$/i.test(writtenName);
    if (writtenName && !pronoun && !services.nameMatches(writtenName, employee)) return false;
    if (!semantic && permitted.employees.some((row: any) =>
      String(row.id) !== context.employeeId && services.nameMatches(request.content, row))) return false;
    const date = services.resolveDate(semantic?.requested_date || "unspecified", request.content, context.shiftDate);
    if (!date) return false;
    await services.clearState();
    await services.report(employee, date, semantic?.intent === "employee_shift" ? "shift" : "attendance");
    return true;
  } catch (error) {
    await services.failed(error);
    return true;
  }
}
