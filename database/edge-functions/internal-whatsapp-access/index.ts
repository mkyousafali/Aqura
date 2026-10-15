import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const supabase = createClient(Deno.env.get("SUPABASE_URL") || "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
  try {
    const { data: jobs, error } = await supabase.from("wa_internal_access_jobs").select("*,wa_accounts!inner(access_token,phone_number_id)")
      .in("status", ["pending", "failed"]).lte("next_attempt_at", new Date().toISOString()).order("created_at").limit(50);
    if (error) throw error;
    let completed = 0;
    for (const job of jobs || []) {
      await supabase.from("wa_internal_access_jobs").update({ status: "processing", attempts: job.attempts + 1, updated_at: new Date().toISOString() }).eq("id", job.id);
      const endpoint = job.operation === "block" ? "block_users" : "unblock_users";
      const response = await fetch(`https://graph.facebook.com/v22.0/${job.wa_accounts.phone_number_id}/${endpoint}`, {
        method: "POST", headers: { Authorization: `Bearer ${job.wa_accounts.access_token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ messaging_product: "whatsapp", [endpoint]: [{ user: job.phone_number }] }),
      });
      if (response.ok) {
        completed++;
        await supabase.from("wa_internal_access_jobs").update({ status: "completed", last_error: null, updated_at: new Date().toISOString() }).eq("id", job.id);
        await supabase.from("wa_internal_security_audit").insert({ account_id: job.account_id, phone_number: job.phone_number,
          event_type: job.operation === "block" ? "blocked" : "unblocked", details: { job_id: job.id } });
      } else {
        const failure = await response.text();
        const delayMinutes = Math.min(60, Math.pow(2, Math.min(job.attempts, 6)));
        await supabase.from("wa_internal_access_jobs").update({ status: "failed", last_error: failure,
          next_attempt_at: new Date(Date.now() + delayMinutes * 60000).toISOString(), updated_at: new Date().toISOString() }).eq("id", job.id);
      }
    }
    return new Response(JSON.stringify({ success: true, processed: jobs?.length || 0, completed }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
