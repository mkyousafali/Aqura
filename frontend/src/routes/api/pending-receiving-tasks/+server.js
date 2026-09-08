// Mirrors /api/receiving-tasks but targets records that live in pending_receiving_records
// instead of receiving_records (Start Receiving bill types other than "Original Bill").
// The original /api/receiving-tasks route is untouched.
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

    // Call the database function to process clearance certificate generation
    // for a PENDING receiving record
    const { data, error } = await supabase.rpc(
      "process_pending_clearance_certificate_generation",
      {
        receiving_record_id_param: receiving_record_id,
        clearance_certificate_url_param: clearance_certificate_url,
        generated_by_user_id: generated_by_user_id,
        generated_by_name: generated_by_name || null,
        generated_by_role: generated_by_role || null,
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
      message: `Successfully generated ${data.tasks_created} tasks and sent ${data.notifications_sent} notifications`,
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
    const { data, error } = await supabase.rpc(
      "get_tasks_for_pending_receiving_record",
      {
        receiving_record_id_param: receiving_record_id,
      },
    );

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
