// Auto Task ingestion for records that live in pending_receiving_records.
import { json } from "@sveltejs/kit";
import { supabase } from "$lib/utils/supabase";

export async function POST({ request }) {
  try {
    const {
      receiving_record_id,
      clearance_certificate_url,
      generated_by_user_id,
      generated_by_name,
      generated_by_role,
    } = await request.json();

    // Validate required fields
    if (!receiving_record_id) {
      return json(
        { error: "Receiving record ID is required" },
        { status: 400 },
      );
    }

    if (!clearance_certificate_url) {
      return json(
        { error: "Clearance certificate URL is required" },
        { status: 400 },
      );
    }

    if (!generated_by_user_id) {
      return json({ error: "User ID is required" }, { status: 400 });
    }

    // Development cutover: use the isolated Auto Task system for pending
    // receiving records. The legacy flow is intentionally not called.
    const { data, error } = await supabase.rpc(
      "Autotask_ingest_receiving_certificate",
      {
        p_source_table: "pending_receiving_records",
        p_source_record_id: String(receiving_record_id),
        p_certificate_url: clearance_certificate_url,
        p_actor_user_id: generated_by_user_id,
      },
    );

    if (error) {
      console.error(
        "Database error generating clearance certificate tasks (pending):",
        error,
      );
      return json(
        {
          error:
            "Failed to generate clearance certificate tasks: " + error.message,
        },
        { status: 500 },
      );
    }

    // Check if the response indicates success
    if (data && !data.success) {
      return json(
        {
          error: data.error || "Unknown error occurred",
          error_code: data.error_code,
        },
        { status: 400 },
      );
    }

    return json({
      success: true,
      data: data,
      message: data.duplicate
        ? "Auto Tasks already exist for this pending receiving record"
        : `Successfully generated ${data.tasks_created} Auto Tasks`,
    });
  } catch (error) {
    console.error("Error generating clearance certificate tasks (pending):", error);
    return json(
      {
        error: "Internal server error: " + error.message,
      },
      { status: 500 },
    );
  }
}

export async function GET({ url }) {
  try {
    const receiving_record_id = url.searchParams.get("receiving_record_id");

    if (!receiving_record_id) {
      return json(
        { error: "receiving_record_id is required" },
        { status: 400 },
      );
    }

    console.log(
      "Fetching tasks for pending receiving_record_id:",
      receiving_record_id,
    );
    const { data, error } = await supabase.rpc("Autotask_get_source_tasks", {
      p_source_table: "pending_receiving_records",
      p_source_record_id: receiving_record_id,
    });

    if (error) {
      console.error("Database error fetching pending receiving record tasks:", error);
      console.error("Error details:", JSON.stringify(error, null, 2));
      return json(
        {
          error: "Failed to fetch tasks: " + error.message,
          details: error,
        },
        { status: 500 },
      );
    }

    // Return empty array if no tasks found instead of error
    return json({
      success: true,
      tasks: data || [],
      message:
        data && data.length > 0 ? "Tasks found" : "No tasks generated yet",
    });
  } catch (error) {
    console.error("Error fetching pending receiving tasks:", error);
    return json({ error: "Internal server error" }, { status: 500 });
  }
}
