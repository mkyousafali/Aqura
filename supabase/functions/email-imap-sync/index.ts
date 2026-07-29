import { serve } from "https://deno.land/std@0.177.1/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Read IMAP response (may be multiline)
async function readImapResponse(conn: any, tag?: string): Promise<string> {
  let result = "";
  const decoder = new TextDecoder();
  const buf = new Uint8Array(8192);
  
  while (true) {
    const n = await conn.read(buf);
    if (!n) break;
    result += decoder.decode(buf.subarray(0, n));
    // Check if we have a complete tagged response
    if (tag && (result.includes(`${tag} OK`) || result.includes(`${tag} NO`) || result.includes(`${tag} BAD`))) break;
    // For untagged, check if we have a complete line
    if (!tag && result.endsWith("\r\n")) break;
    // Safety: don't loop forever
    if (result.length > 500000) break;
  }
  return result;
}

async function sendImapCmd(conn: any, tag: string, cmd: string): Promise<string> {
  await conn.write(new TextEncoder().encode(`${tag} ${cmd}\r\n`));
  return await readImapResponse(conn, tag);
}

// Parse a simple email header from FETCH response
function parseHeaders(fetchData: string): { subject: string; from: string; fromName: string; date: string; messageId: string; inReplyTo: string; references: string } {
  const getHeader = (name: string): string => {
    const regex = new RegExp(`^${name}:\\s*(.+?)(?=\\r?\\n[^ \\t]|$)`, "im");
    const match = fetchData.match(regex);
    return match ? match[1].trim() : "";
  };

  const from = getHeader("From");
  let fromName = "";
  let fromAddr = from;
  const nameMatch = from.match(/^"?([^"<]+)"?\s*<(.+?)>/);
  if (nameMatch) { fromName = nameMatch[1].trim(); fromAddr = nameMatch[2]; }

  return {
    subject: getHeader("Subject"),
    from: fromAddr,
    fromName: fromName,
    date: getHeader("Date"),
    messageId: getHeader("Message-ID") || getHeader("Message-Id"),
    inReplyTo: getHeader("In-Reply-To"),
    references: getHeader("References"),
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

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
    const { account_id } = body;
    if (!account_id) return json({ error: "Missing account_id" }, 400);

    // Load account
    const { data: account } = await supabase.from("email_accounts").select("*").eq("id", account_id).single();
    if (!account || !account.sync_enabled) return json({ error: "Account not found or sync disabled" }, 400);

    // Load secrets
    const { data: secrets } = await supabase.from("email_account_secrets").select("encrypted_imap_password").eq("email_account_id", account_id).single();
    let imapPassword = "";
    if (secrets?.encrypted_imap_password) {
      try { imapPassword = atob(secrets.encrypted_imap_password); } catch {}
    }
    if (!imapPassword) return json({ error: "No IMAP password configured" }, 400);

    const host = account.imap_host;
    const port = account.imap_port || 993;
    const username = account.imap_username || account.email_address;

    if (!host) return json({ error: "No IMAP host configured" }, 400);

    // Connect via TLS (port 993)
    let conn: any;
    try {
      conn = await Deno.connectTls({ hostname: host, port });
    } catch (err: any) {
      return json({ error: `IMAP connection failed: ${err.message}` }, 500);
    }

    // Read greeting
    const greeting = await readImapResponse(conn);
    if (!greeting.includes("OK")) {
      conn.close();
      return json({ error: "IMAP server rejected connection" }, 500);
    }

    // Login
    let tagNum = 1;
    const tag = () => `A${String(tagNum++).padStart(3, "0")}`;

    const loginResp = await sendImapCmd(conn, tag(), `LOGIN "${username}" "${imapPassword}"`);
    if (!loginResp.includes("OK")) {
      conn.close();
      return json({ error: "IMAP login failed" }, 401);
    }

    // Ensure inbox folder exists in DB
    let { data: inboxFolder } = await supabase.from("email_folders")
      .select("id, last_synced_uid, uid_validity")
      .eq("email_account_id", account_id)
      .eq("folder_type", "inbox")
      .single();

    if (!inboxFolder) {
      const { data: newFolder } = await supabase.from("email_folders").insert({
        email_account_id: account_id, remote_folder_name: "INBOX",
        display_name: "Inbox", folder_type: "inbox"
      }).select("id, last_synced_uid, uid_validity").single();
      inboxFolder = newFolder;
    }

    // Also create sent folder if not exists
    const { data: sentFolder } = await supabase.from("email_folders")
      .select("id").eq("email_account_id", account_id).eq("folder_type", "sent").single();
    if (!sentFolder) {
      await supabase.from("email_folders").insert({
        email_account_id: account_id, remote_folder_name: "Sent",
        display_name: "Sent", folder_type: "sent"
      });
    }

    // SELECT INBOX
    const selectResp = await sendImapCmd(conn, tag(), "SELECT INBOX");
    
    // Parse UIDVALIDITY and EXISTS count
    const uidValidityMatch = selectResp.match(/UIDVALIDITY\s+(\d+)/);
    const existsMatch = selectResp.match(/\*\s+(\d+)\s+EXISTS/);
    const uidValidity = uidValidityMatch ? parseInt(uidValidityMatch[1]) : 0;
    const totalMessages = existsMatch ? parseInt(existsMatch[1]) : 0;

    if (totalMessages === 0) {
      await sendImapCmd(conn, tag(), "LOGOUT");
      conn.close();
      await supabase.from("email_accounts").update({ last_sync_at: new Date().toISOString(), last_sync_status: "success" }).eq("id", account_id);
      return json({ success: true, synced: 0, total: 0 });
    }

    // Get last synced UID
    const lastUid = inboxFolder?.last_synced_uid || 0;

    // Fetch new messages (UID > lastUid) - limit to 50 newest
    const searchCmd = lastUid > 0 ? `UID SEARCH UID ${lastUid + 1}:*` : `UID SEARCH ALL`;
    const searchResp = await sendImapCmd(conn, tag(), searchCmd);
    
    // Parse UIDs from search response
    const searchLine = searchResp.split("\r\n").find(l => l.startsWith("* SEARCH"));
    const uids: number[] = searchLine 
      ? searchLine.replace("* SEARCH", "").trim().split(/\s+/).filter(Boolean).map(Number).filter(n => n > lastUid)
      : [];

    // Limit to newest 50
    const uidsToFetch = uids.slice(-50);
    let syncedCount = 0;
    let maxUid = lastUid;

    for (const uid of uidsToFetch) {
      try {
        // Fetch headers and body
        const fetchResp = await sendImapCmd(conn, tag(), 
          `UID FETCH ${uid} (FLAGS BODY[HEADER] BODY[TEXT])`);

        // Parse headers
        const headers = parseHeaders(fetchResp);
        
        // Check for duplicate
        if (headers.messageId) {
          const { data: existing } = await supabase.from("email_messages")
            .select("id").eq("email_account_id", account_id).eq("message_id_header", headers.messageId).single();
          if (existing) { maxUid = Math.max(maxUid, uid); continue; }
        }

        // Extract body text (simplified - between BODY[TEXT] markers)
        let bodyText = "";
        const textStart = fetchResp.indexOf("\r\n\r\n", fetchResp.indexOf("BODY[TEXT]"));
        if (textStart > -1) {
          const textEnd = fetchResp.lastIndexOf("\r\n)");
          if (textEnd > textStart) bodyText = fetchResp.substring(textStart + 4, textEnd);
        }

        // Determine if read
        const isRead = fetchResp.includes("\\Seen");
        const isFlagged = fetchResp.includes("\\Flagged");

        // Parse date
        let receivedAt = new Date().toISOString();
        if (headers.date) {
          try { receivedAt = new Date(headers.date).toISOString(); } catch {}
        }

        // Insert message
        const { data: msg } = await supabase.from("email_messages").insert({
          email_account_id: account_id,
          folder_id: inboxFolder!.id,
          remote_uid: uid,
          uid_validity: uidValidity,
          message_id_header: headers.messageId || null,
          in_reply_to_header: headers.inReplyTo || null,
          references_header: headers.references || null,
          direction: "inbound",
          status: "received",
          subject: headers.subject || "(no subject)",
          from_name: headers.fromName || null,
          from_address: headers.from || "unknown",
          text_body: bodyText,
          body_preview: bodyText.substring(0, 200).replace(/\s+/g, " "),
          received_at: receivedAt,
          is_read: isRead,
          is_flagged: isFlagged,
          source_type: "imap_sync",
        }).select("id").single();

        // Insert sender as recipient record (from)
        if (msg) {
          await supabase.from("email_message_recipients").insert({
            email_message_id: msg.id,
            recipient_type: "to",
            email_address: account.email_address,
            display_name: account.from_name || account.account_name,
          });
        }

        maxUid = Math.max(maxUid, uid);
        syncedCount++;
      } catch (err) {
        console.error(`Error syncing UID ${uid}:`, err);
      }
    }

    // Update last synced UID
    if (maxUid > lastUid) {
      await supabase.from("email_folders").update({ 
        last_synced_uid: maxUid, uid_validity: uidValidity, last_sync_at: new Date().toISOString() 
      }).eq("id", inboxFolder!.id);
    }

    // Logout
    await sendImapCmd(conn, tag(), "LOGOUT");
    try { conn.close(); } catch {}

    // Update account sync status
    await supabase.from("email_accounts").update({
      last_sync_at: new Date().toISOString(), last_sync_status: "success"
    }).eq("id", account_id);

    // Log
    await supabase.from("email_logs").insert({
      event_type: "sync_completed", email_account_id: account_id,
      safe_message: `IMAP sync complete: ${syncedCount} new messages (${totalMessages} total in INBOX)`,
    });

    return json({ success: true, synced: syncedCount, total: totalMessages });
  } catch (err: any) {
    return json({ error: "Sync error: " + err.message }, 500);
  }
});
