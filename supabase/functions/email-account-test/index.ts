import { serve } from "https://deno.land/std@0.177.1/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
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
    const { account_id, test_type } = body;

    if (!account_id || !test_type) {
      return new Response(
        JSON.stringify({ error: "Missing account_id or test_type" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Load account config
    const { data: account, error: accError } = await supabase
      .from("email_accounts")
      .select("*")
      .eq("id", account_id)
      .single();

    if (accError || !account) {
      return new Response(
        JSON.stringify({ error: "Account not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Load encrypted credentials
    const { data: secrets } = await supabase
      .from("email_account_secrets")
      .select("encrypted_smtp_password, encrypted_imap_password")
      .eq("email_account_id", account_id)
      .single();

    // Decrypt credentials using the master key
    const encryptionKey = Deno.env.get("EMAIL_ENCRYPTION_KEY") ?? "";

    let testResult: { success: boolean; error?: string; details?: string } = { success: false };

    if (test_type === "smtp") {
      // Test SMTP connection
      try {
        const host = account.smtp_host;
        const port = account.smtp_port || 587;
        const encryption = account.smtp_encryption || "tls";

        if (!host) {
          testResult = { success: false, error: "SMTP host not configured" };
        } else if (encryption === "ssl" || port === 465) {
          // Direct TLS connection (port 465 / SSL)
          const conn = await Deno.connectTls({ hostname: host, port: port });
          const buf = new Uint8Array(1024);
          const n = await conn.read(buf);
          const greeting = new TextDecoder().decode(buf.subarray(0, n || 0));
          
          if (greeting.startsWith("220")) {
            await conn.write(new TextEncoder().encode("EHLO aqura.local\r\n"));
            const resp = new Uint8Array(2048);
            await conn.read(resp);
            testResult = { success: true, details: `SSL connected to ${host}:${port}` };
          } else {
            testResult = { success: false, error: `Unexpected greeting: ${greeting.substring(0, 100)}` };
          }
          await conn.write(new TextEncoder().encode("QUIT\r\n"));
          conn.close();
        } else {
          // STARTTLS connection (port 587 / TLS) 
          const tcpConn = await Deno.connect({ hostname: host, port: port });
          const buf = new Uint8Array(1024);
          const n = await tcpConn.read(buf);
          const greeting = new TextDecoder().decode(buf.subarray(0, n || 0));
          
          if (!greeting.startsWith("220")) {
            tcpConn.close();
            testResult = { success: false, error: `Unexpected greeting: ${greeting.substring(0, 100)}` };
          } else {
            // Send EHLO
            await tcpConn.write(new TextEncoder().encode("EHLO aqura.local\r\n"));
            const ehloResp = new Uint8Array(2048);
            await tcpConn.read(ehloResp);
            
            // Send STARTTLS
            await tcpConn.write(new TextEncoder().encode("STARTTLS\r\n"));
            const tlsResp = new Uint8Array(1024);
            const tn = await tcpConn.read(tlsResp);
            const tlsGreeting = new TextDecoder().decode(tlsResp.subarray(0, tn || 0));
            
            if (tlsGreeting.startsWith("220")) {
              // Upgrade to TLS
              const tlsConn = await Deno.startTls(tcpConn, { hostname: host });
              
              // Send EHLO again over TLS
              await tlsConn.write(new TextEncoder().encode("EHLO aqura.local\r\n"));
              const secResp = new Uint8Array(2048);
              await tlsConn.read(secResp);
              
              testResult = { success: true, details: `STARTTLS connected to ${host}:${port}` };
              await tlsConn.write(new TextEncoder().encode("QUIT\r\n"));
              tlsConn.close();
            } else {
              testResult = { success: false, error: `STARTTLS rejected: ${tlsGreeting.substring(0, 100)}` };
              await tcpConn.write(new TextEncoder().encode("QUIT\r\n"));
              tcpConn.close();
            }
          }
        }
      } catch (err: any) {
        testResult = { success: false, error: `SMTP connection failed: ${err.message}` };
      }

      // Update account test status
      await supabase
        .from("email_accounts")
        .update({
          last_smtp_test_at: new Date().toISOString(),
          last_smtp_test_status: testResult.success ? "success" : "failed",
        })
        .eq("id", account_id);

    } else if (test_type === "imap") {
      // Test IMAP connection with authentication
      console.log("Starting IMAP test for account:", account_id);
      try {
        const host = account.imap_host;
        const port = account.imap_port || 993;
        const username = account.imap_username || account.email_address;
        console.log("IMAP config:", host, port, username);

        if (!host) {
          testResult = { success: false, error: "IMAP host not configured" };
        } else {
          // Load IMAP password
          let imapPassword = "";
          if (secrets?.encrypted_imap_password) {
            try { imapPassword = atob(secrets.encrypted_imap_password); } catch {}
          }

          // Connect via TLS (port 993)
          const conn = await Deno.connectTls({ hostname: host, port: port });
          
          // Read greeting
          const buf = new Uint8Array(2048);
          const n = await conn.read(buf);
          const greeting = new TextDecoder().decode(buf.subarray(0, n || 0));
          
          if (!greeting.includes("OK")) {
            conn.close();
            testResult = { success: false, error: `IMAP server rejected: ${greeting.substring(0, 100)}` };
          } else if (!imapPassword) {
            // Connection OK but no password to test auth
            await conn.write(new TextEncoder().encode("A001 LOGOUT\r\n"));
            conn.close();
            testResult = { success: true, details: `Connected to ${host}:${port} (no password to test login)` };
          } else {
            // Try LOGIN
            await conn.write(new TextEncoder().encode(`A001 LOGIN "${username}" "${imapPassword}"\r\n`));
            const loginBuf = new Uint8Array(2048);
            const ln = await conn.read(loginBuf);
            const loginResp = new TextDecoder().decode(loginBuf.subarray(0, ln || 0));
            
            if (loginResp.includes("A001 OK")) {
              testResult = { success: true, details: `Authenticated to ${host}:${port}` };
            } else {
              testResult = { success: false, error: `IMAP login failed for ${username}` };
            }
            
            await conn.write(new TextEncoder().encode("A002 LOGOUT\r\n"));
            conn.close();
          }
        }
      } catch (err: any) {
        testResult = { success: false, error: `IMAP connection failed: ${err.message}` };
      }

      // Update account test status
      await supabase
        .from("email_accounts")
        .update({
          last_imap_test_at: new Date().toISOString(),
          last_imap_test_status: testResult.success ? "success" : "failed",
        })
        .eq("id", account_id);
    } else {
      testResult = { success: false, error: "Invalid test_type. Use 'smtp' or 'imap'" };
    }

    // Log the test
    await supabase.from("email_logs").insert({
      event_type: `${test_type}_test`,
      email_account_id: account_id,
      safe_message: testResult.success
        ? `${test_type.toUpperCase()} test successful for ${account.email_address}`
        : `${test_type.toUpperCase()} test failed for ${account.email_address}: ${testResult.error}`,
    });

    return new Response(
      JSON.stringify(testResult),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: "Internal error", details: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
