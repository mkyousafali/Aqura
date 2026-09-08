import { json } from "@sveltejs/kit";
import { db } from "$lib/utils/supabase";

/** @type {import('./$types').RequestHandler} */
export async function POST({ request }) {
  try {
    const { title, description, created_by } = await request.json();

    // Validate required fields
    if (!title || !title.trim()) {
      return json({ error: "Title is required" }, { status: 400 });
    }

    // Create task data with all required fields
    const taskData = {
      title: title.trim(),
      description: description?.trim() || "",
      status: /** @type {'draft'} */ ("draft"), // Default status for new tasks
      priority: /** @type {'medium'} */ ("medium"), // Default priority
      created_by: created_by,
      // Required boolean fields for Task type
      require_task_finished: false,
      require_photo_upload: false,
      require_erp_reference: false,
      can_escalate: true,
      can_reassign: true,
    };

    // Insert task into database
    const result = await db.tasks.create(taskData);

    if (result.error) {
      console.error("Database error creating task:", result.error);
      return json(
        { error: "Failed to create task: " + result.error.message },
        { status: 500 },
      );
    }

    return json({
      success: true,
      task: result.data,
      message: "Task created successfully",
    });
  } catch (error) {
    console.error("Error creating task:", error);
    return json(
      { error: "Internal server error: " + error.message },
      { status: 500 },
    );
  }
}

/** @type {import('./$types').RequestHandler} */
export async function GET() {
  try {
    // Get tasks from database
    const result = await db.tasks.getAll();

    if (result.error) {
      console.error("Database error fetching tasks:", result.error);
      return json({ error: "Failed to fetch tasks" }, { status: 500 });
    }

    return json({
      success: true,
      tasks: result.data || [],
    });
  } catch (error) {
    console.error("Error fetching tasks:", error);
    return json({ error: "Internal server error" }, { status: 500 });
  }
}
