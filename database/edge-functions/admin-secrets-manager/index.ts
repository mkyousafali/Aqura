import { serve } from "https://deno.land/std@0.177.1/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const ALLOWED_SECRETS = ["supabase_url", "anon_key", "service_role_key"];

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();
    const { action, user_id } = body;

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "Missing user_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify caller is a master admin
    const { data: userRow, error: userError } = await supabase
      .from("users")
      .select("id, is_master_admin")
      .eq("id", user_id)
      .single();

    if (userError || !userRow || !userRow.is_master_admin) {
      return new Response(
        JSON.stringify({ error: "Forbidden: master admin only" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (action === "status") {
      const { data, error } = await supabase.rpc("admin_secret_status");
      if (error) {
        return new Response(
          JSON.stringify({ error: error.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      return new Response(
        JSON.stringify({ secrets: data }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (action === "save") {
      const { secrets } = body;
      if (!secrets || typeof secrets !== "object") {
        return new Response(
          JSON.stringify({ error: "Missing secrets object" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      for (const key of Object.keys(secrets)) {
        if (!ALLOWED_SECRETS.includes(key)) {
          return new Response(
            JSON.stringify({ error: `Unknown secret name: ${key}` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
        const value = secrets[key];
        if (!value || typeof value !== "string" || !value.trim()) {
          continue; // skip empty fields, don't overwrite with blank
        }
        const { error } = await supabase.rpc("admin_upsert_secret", {
          secret_name: key,
          secret_value: value.trim(),
        });
        if (error) {
          return new Response(
            JSON.stringify({ error: `Failed to save ${key}: ${error.message}` }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      return new Response(
        JSON.stringify({ success: true }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Unknown action" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e: any) {
    return new Response(
      JSON.stringify({ error: e.message || "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
