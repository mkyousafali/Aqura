import { serve } from "https://deno.land/std@0.177.1/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Helper: read SMTP response
async function readResponse(conn: any): Promise<string> {
  const buf = new Uint8Array(4096);
  const n = await conn.read(buf);
  return new TextDecoder().decode(buf.subarray(0, n || 0));
}

// Helper: send SMTP command and read response
async function sendCmd(conn: any, cmd: string): Promise<string> {
  await conn.write(new TextEncoder().encode(cmd + "\r\n"));
  return await readResponse(conn);
}

// Helper: build RFC822 email
function buildEmail(from: string, fromName: string, toList: string[], ccList: string[], subject: string, textBody: string, htmlBody: string, messageId: string): string {
  const boundary = "----=_Part_" + Date.now().toString(36);
  const date = new Date().toUTCString();
  
  let msg = `From: ${fromName ? `${fromName} <${from}>` : from}\r\n`;
  msg += `To: ${toList.join(", ")}\r\n`;
  if (ccList.length > 0) msg += `Cc: ${ccList.join(", ")}\r\n`;
  msg += `Subject: ${subject}\r\n`;
  msg += `Date: ${date}\r\n`;
  msg += `Message-ID: ${messageId}\r\n`;
  msg += `MIME-Version: 1.0\r\n`;
  
  if (htmlBody) {
    msg += `Content-Type: multipart/alternative; boundary="${boundary}"\r\n`;
    msg += `\r\n`;
    msg += `--${boundary}\r\n`;
    msg += `Content-Type: text/plain; charset="UTF-8"\r\n\r\n`;
    msg += (textBody || "").replace(/\r?\n/g, "\r\n") + "\r\n";
    msg += `--${boundary}\r\n`;
    msg += `Content-Type: text/html; charset="UTF-8"\r\n\r\n`;
    msg += htmlBody.replace(/\r?\n/g, "\r\n") + "\r\n";
    msg += `--${boundary}--\r\n`;
  } else {
    msg += `Content-Type: text/plain; charset="UTF-8"\r\n\r\n`;
    msg += (textBody || "").replace(/\r?\n/g, "\r\n");
  }
  
  return msg;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (data: any, status = 200) => new Response(
    JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing authorization" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();
    const { queue_id } = body;
    if (!queue_id) return json({ error: "Missing queue_id" }, 400);

    // Load queue item
    const { data: queueItem } = await supabase.from("email_queue").select("*").eq("id", queue_id).single();
    if (!queueItem) return json({ error: "Queue item not found" }, 404);
    if (queueItem.status === "sent" || queueItem.status === "completed") return json({ success: true, message: "Already sent" });

    // Lock
    await supabase.from("email_queue").update({ status: "processing", locked_at: new Date().toISOString(), locked_by: "email-send" }).eq("id", queue_id);

    // Load message, recipients, account, secrets
    const { data: message } = await supabase.from("email_messages").select("*").eq("id", queueItem.email_message_id).single();
    if (!message) {
      await supabase.from("email_queue").update({ status: "permanent_failed", last_error_message: "Message not found" }).eq("id", queue_id);
      return json({ error: "Message not found" }, 404);
    }

    const { data: recipients } = await supabase.from("email_message_recipients").select("*").eq("email_message_id", message.id);
    const { data: account } = await supabase.from("email_accounts").select("*").eq("id", queueItem.email_account_id).single();
    if (!account?.send_enabled) {
      await supabase.from("email_queue").update({ status: "permanent_failed", last_error_message: "Account disabled" }).eq("id", queue_id);
      return json({ error: "Account disabled" }, 400);
    }

    const { data: secrets } = await supabase.from("email_account_secrets").select("encrypted_smtp_password").eq("email_account_id", account.id).single();

    // Decode password (base64 stored)
    let smtpPassword = "";
    if (secrets?.encrypted_smtp_password) {
      try { smtpPassword = atob(secrets.encrypted_smtp_password); } catch { smtpPassword = ""; }
    }

    if (!smtpPassword) {
      await supabase.from("email_queue").update({ status: "permanent_failed", last_error_message: "No SMTP password configured" }).eq("id", queue_id);
      return json({ error: "No SMTP password" }, 400);
    }

    // Record attempt
    const attemptNumber = (queueItem.attempt_count || 0) + 1;
    const attemptStart = new Date();
    const { data: attempt } = await supabase.from("email_send_attempts").insert({
      email_queue_id: queue_id, email_message_id: message.id, attempt_number: attemptNumber
    }).select("id").single();

    // Prepare recipients
    const toAddresses = (recipients || []).filter((r: any) => r.recipient_type === "to").map((r: any) => r.email_address);
    const ccAddresses = (recipients || []).filter((r: any) => r.recipient_type === "cc").map((r: any) => r.email_address);
    const bccAddresses = (recipients || []).filter((r: any) => r.recipient_type === "bcc").map((r: any) => r.email_address);
    const allRecipients = [...toAddresses, ...ccAddresses, ...bccAddresses];

    if (allRecipients.length === 0) {
      await supabase.from("email_queue").update({ status: "permanent_failed", last_error_message: "No recipients" }).eq("id", queue_id);
      return json({ error: "No recipients" }, 400);
    }

    // Send via raw SMTP
    let sendError = "";
    try {
      const host = account.smtp_host;
      const port = account.smtp_port || 587;
      const encryption = account.smtp_encryption || "tls";
      const username = account.smtp_username || account.email_address;

      let conn: any;

      if (encryption === "ssl" || port === 465) {
        // Direct SSL
        conn = await Deno.connectTls({ hostname: host, port });
        await readResponse(conn); // greeting
      } else {
        // STARTTLS
        const tcpConn = await Deno.connect({ hostname: host, port });
        await readResponse(tcpConn); // greeting
        await sendCmd(tcpConn, `EHLO aqura.local`);
        const starttlsResp = await sendCmd(tcpConn, "STARTTLS");
        if (!starttlsResp.startsWith("220")) throw new Error("STARTTLS rejected: " + starttlsResp.trim());
        conn = await Deno.startTls(tcpConn, { hostname: host });
      }

      // EHLO after TLS
      await sendCmd(conn, `EHLO aqura.local`);

      // AUTH LOGIN
      const authResp = await sendCmd(conn, "AUTH LOGIN");
      if (!authResp.startsWith("334")) throw new Error("AUTH not supported: " + authResp.trim());
      
      const userResp = await sendCmd(conn, btoa(username));
      if (!userResp.startsWith("334")) throw new Error("Username rejected: " + userResp.trim());
      
      const passResp = await sendCmd(conn, btoa(smtpPassword));
      if (!passResp.startsWith("235")) throw new Error("Authentication failed");

      // MAIL FROM
      const fromResp = await sendCmd(conn, `MAIL FROM:<${account.email_address}>`);
      if (!fromResp.startsWith("250")) throw new Error("MAIL FROM rejected: " + fromResp.trim());

      // RCPT TO for each recipient
      for (const rcpt of allRecipients) {
        const rcptResp = await sendCmd(conn, `RCPT TO:<${rcpt}>`);
        if (!rcptResp.startsWith("250")) throw new Error(`RCPT TO <${rcpt}> rejected: ${rcptResp.trim()}`);
      }

      // DATA
      const dataResp = await sendCmd(conn, "DATA");
      if (!dataResp.startsWith("354")) throw new Error("DATA rejected: " + dataResp.trim());

      // Build and send email content
      const messageId = message.message_id_header || `<${message.id}@aqura.email>`;
      const emailContent = buildEmail(
        account.email_address, account.from_name || account.account_name,
        toAddresses, ccAddresses,
        message.subject || "", message.text_body || "", message.html_body || "",
        messageId
      );

      await conn.write(new TextEncoder().encode(emailContent + "\r\n.\r\n"));
      const endResp = await readResponse(conn);
      if (!endResp.startsWith("250")) throw new Error("Send rejected: " + endResp.trim());

      // QUIT
      await sendCmd(conn, "QUIT");
      try { conn.close(); } catch {}

    } catch (err: any) {
      sendError = err.message || "Unknown SMTP error";
    }

    const attemptEnd = new Date();
    const durationMs = attemptEnd.getTime() - attemptStart.getTime();

    // Update attempt record
    if (attempt) {
      await supabase.from("email_send_attempts").update({
        completed_at: attemptEnd.toISOString(),
        result: sendError ? "temporary_failure" : "success",
        safe_error_message: sendError || null,
        duration_ms: durationMs,
      }).eq("id", attempt.id);
    }

    if (!sendError) {
      // Success
      await supabase.from("email_queue").update({
        status: "sent", processing_finished_at: attemptEnd.toISOString(),
        attempt_count: attemptNumber, locked_at: null, locked_by: null,
      }).eq("id", queue_id);

      await supabase.from("email_messages").update({ status: "sent", sent_at: attemptEnd.toISOString() }).eq("id", message.id);

      await supabase.from("email_logs").insert({
        event_type: "message_sent", email_account_id: account.id,
        email_message_id: message.id, queue_item_id: queue_id,
        safe_message: `Email sent to ${toAddresses.join(", ")}`,
      });

      return json({ success: true, message: "Email sent successfully" });
    } else {
      // Failure
      const isPermanent = attemptNumber >= (queueItem.maximum_attempts || 3);
      await supabase.from("email_queue").update({
        status: isPermanent ? "permanent_failed" : "temporary_failed",
        attempt_count: attemptNumber, last_error_message: sendError,
        next_retry_at: isPermanent ? null : new Date(Date.now() + Math.pow(2, attemptNumber) * 60000).toISOString(),
        locked_at: null, locked_by: null,
      }).eq("id", queue_id);

      if (isPermanent) await supabase.from("email_messages").update({ status: "failed" }).eq("id", message.id);

      await supabase.from("email_logs").insert({
        event_type: "message_failed", email_account_id: account.id,
        email_message_id: message.id, queue_item_id: queue_id,
        safe_message: `Send failed (attempt ${attemptNumber}): ${sendError}`,
      });

      return json({ success: false, error: sendError, attempt: attemptNumber, permanent: isPermanent }, isPermanent ? 422 : 503);
    }
  } catch (err: any) {
    return json({ error: "Internal error", details: err.message }, 500);
  }
});
