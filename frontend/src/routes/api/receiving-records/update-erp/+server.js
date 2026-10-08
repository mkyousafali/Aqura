import { json } from "@sveltejs/kit";
import {
  databaseClient,
  requireBreakUser,
} from "$lib/server/breakRegisterAuth";

/** @type {import('./$types').RequestHandler} */
export async function POST({ request, cookies }) {
  try {
    await requireBreakUser(cookies, "desktop");
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

    // Update the receiving record with the ERP reference
    const { data, error } = await databaseClient()
      .from("receiving_records")
      .update({
        erp_purchase_invoice_reference: erpReference.trim(),
        erp_purchase_invoice_uploaded: true,
        updated_at: new Date().toISOString(),
      })
      .eq("id", receivingRecordId)
      .select("id, erp_purchase_invoice_reference")
      .maybeSingle();

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

    return json({
      success: true,
      data: data,
      message: "ERP invoice reference updated successfully",
    });
  } catch (error) {
    console.error("Error updating ERP reference:", error);
    const message = error instanceof Error ? error.message : "Internal server error";
    const status = /session|authentication|access/i.test(message) ? 401 : 500;
    return json({ error: message }, { status });
  }
}
