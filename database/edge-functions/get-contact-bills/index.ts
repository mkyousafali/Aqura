import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone_number, base_url } = await req.json();

    if (!phone_number) {
      return new Response(
        JSON.stringify({ error: "phone_number is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Create Supabase client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") || "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // 1. Get all active ERP connections with branch location data
    const { data: erpConfigs, error: configError } = await supabase
      .from("erp_connections")
      .select(
        "tunnel_url, erp_branch_id, branch_id, branch_name, branches(id, location_en, location_ar)"
      )
      .eq("is_active", true)
      .order("branch_id");

    if (configError) throw configError;
    if (!erpConfigs || erpConfigs.length === 0) {
      return new Response(
        JSON.stringify({
          branches: [],
          broadcast_stats: {
            sent: 0,
            delivered: 0,
            read: 0,
            failed: 0,
            total: 0,
          },
          total_bills: 0,
          total_amount: 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const mobileNumber = phone_number.trim();

    // 2. Query all branches in parallel
    const branchPromises = erpConfigs.map(async (config: any) => {
      if (!config?.tunnel_url) return null;

      const sql = `SELECT COUNT(*) as bill_cnt, SUM(GrandTotal) as bill_amt FROM InvTransactionMaster 
      WHERE BranchID IN (
        SELECT DISTINCT BranchID FROM PrivilegeCards 
        WHERE REPLACE(Mobile, ' ', '') = '${mobileNumber.replace(/'/g, "''")}'  
      )
      AND LOWER(LTRIM(RTRIM(PartyName))) = (
        SELECT TOP 1 LOWER(LTRIM(RTRIM(CardHolderName))) FROM PrivilegeCards 
        WHERE REPLACE(Mobile, ' ', '') = '${mobileNumber.replace(/'/g, "''")}'  
        AND CardHolderName != ''
      )`;

      try {
        const apiUrl = base_url
          ? `${base_url}/api/erp-products`
          : "http://localhost:5173/api/erp-products";
        const response = await fetch(apiUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            action: "query",
            tunnelUrl: config.tunnel_url,
            sql,
          }),
        });

        const result = await response.json();

        if (result.success && result.recordset?.length > 0) {
          const billCnt = result.recordset[0]?.bill_cnt || 0;
          const billAmt = result.recordset[0]?.bill_amt || 0;

          const branchData = Array.isArray(config.branches)
            ? config.branches[0]
            : config.branches;

          return {
            branch_id: config.branch_id,
            branch_name: config.branch_name || `Branch ${config.branch_id}`,
            location_en: branchData?.location_en || "Location N/A",
            location_ar: branchData?.location_ar || "الموقع غير متاح",
            bill_count: billCnt,
            bill_total: billAmt || 0,
          };
        } else {
          const branchData = Array.isArray(config.branches)
            ? config.branches[0]
            : config.branches;

          return {
            branch_id: config.branch_id,
            branch_name: config.branch_name || `Branch ${config.branch_id}`,
            location_en: branchData?.location_en || "Location N/A",
            location_ar: branchData?.location_ar || "الموقع غير متاح",
            bill_count: 0,
            bill_total: 0,
          };
        }
      } catch (error) {
        console.error(`Error querying branch ${config.branch_id}:`, error);
        const branchData = Array.isArray(config.branches)
          ? config.branches[0]
          : config.branches;

        return {
          branch_id: config.branch_id,
          branch_name: config.branch_name || `Branch ${config.branch_id}`,
          location_en: branchData?.location_en || "Location N/A",
          location_ar: branchData?.location_ar || "الموقع غير متاح",
          bill_count: 0,
          bill_total: 0,
          error: error.message,
        };
      }
    });

    const branchResults = await Promise.all(branchPromises);
    const branches = branchResults.filter((b) => b !== null);

    // 3. Calculate totals
    const totalBills = branches.reduce((sum, b) => sum + b.bill_count, 0);
    const totalAmount = branches.reduce((sum, b) => sum + b.bill_total, 0);

    // 4. Get broadcast stats
    const { data: broadcastStats } = await supabase.rpc(
      "get_contact_broadcast_stats",
      { phone_number }
    );

    const broadcastData = broadcastStats || {
      sent: 0,
      delivered: 0,
      read: 0,
      failed: 0,
      total: 0,
    };

    return new Response(
      JSON.stringify({
        branches,
        broadcast_stats: broadcastData,
        total_bills: totalBills,
        total_amount: totalAmount,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Edge Function Error:", error);
    return new Response(
      JSON.stringify({
        error: error.message || "Internal server error",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
