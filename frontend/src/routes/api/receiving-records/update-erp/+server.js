import { json } from "@sveltejs/kit";
import { supabaseAdmin } from "$lib/utils/supabase";

/** @type {import('./$types').RequestHandler} */
export async function POST({ request }) {
  try {
    const { receivingRecordId, erpReference } = await request.json();

    // Validate input
    if (!receivingRecordId) {
      return json(
        { error: "Receiving record ID is required" },
        { status: 400 },
      );
    }

    if (!erpReference || !erpReference.trim()) {
      return json({ error: "ERP reference is required" }, { status: 400 });
    }

    // Update the receiving record with the ERP reference using admin client to bypass RLS
    const { data, error } = await supabaseAdmin
      .from("receiving_records")
      .update({
        erp_purchase_invoice_reference: erpReference.trim(),
        erp_purchase_invoice_uploaded: true,
        updated_at: new Date().toISOString(),
      })
      .eq("id", receivingRecordId)
      .select()
      .single();

    if (error) {
      console.error("Database error updating ERP reference:", error);
      return json(
        { error: `Database error: ${error.message}` },
        { status: 500 },
      );
    }

    if (!data) {
      return json({ error: "Receiving record not found" }, { status: 404 });
    }

    console.log(
      `ERP reference updated successfully for record ${receivingRecordId}: ${erpReference}`,
    );

    return json({
      success: true,
      data: data,
      message: "ERP invoice reference updated successfully",
    });
  } catch (error) {
    console.error("Error updating ERP reference:", error);
    return json({ error: "Internal server error" }, { status: 500 });
  }
}
