import { supabaseAdmin } from "$lib/utils/supabase";

export async function POST({ request }) {
  try {
    const formData = await request.formData();
    const file = formData.get("file");
    const receiving_record_id = formData.get("receiving_record_id");
    const file_type = formData.get("file_type"); // 'pr_excel' or 'original_bill'

    // Type checking for form data
    if (!(file instanceof File)) {
      return new Response(
        JSON.stringify({
          error: "Invalid file format",
          error_code: "INVALID_FILE_FORMAT",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const receiving_record_id_str = receiving_record_id?.toString();
    const file_type_str = file_type?.toString();

    console.log("📁 [File Upload] Received request:", {
      receiving_record_id: receiving_record_id_str,
      file_type: file_type_str,
      fileName: file.name,
      fileSize: file.size,
    });

    if (!receiving_record_id_str) {
      return new Response(
        JSON.stringify({
          error: "Receiving record ID is required",
          error_code: "MISSING_RECORD_ID",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    if (
      !file_type_str ||
      !["pr_excel", "original_bill"].includes(file_type_str)
    ) {
      return new Response(
        JSON.stringify({
          error: "Valid file_type is required (pr_excel or original_bill)",
          error_code: "INVALID_FILE_TYPE",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Validate file size (10MB limit)
    if (file.size > 10 * 1024 * 1024) {
      return new Response(
        JSON.stringify({
          error: "File size must be less than 10MB",
          error_code: "FILE_TOO_LARGE",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Validate file type for PR Excel
    if (file_type_str === "pr_excel") {
      const isExcel =
        file.name.toLowerCase().includes(".xls") ||
        file.name.toLowerCase().includes(".xlsx");
      if (!isExcel) {
        return new Response(
          JSON.stringify({
            error: "PR Excel file must be a valid Excel file (.xls or .xlsx)",
            error_code: "INVALID_EXCEL_FILE",
          }),
          { status: 400, headers: { "Content-Type": "application/json" } },
        );
      }
    }

    // Create unique file path and determine bucket
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const fileExtension = file.name.split(".").pop();
    const fileName = `${file_type_str}_${receiving_record_id_str}_${timestamp}.${fileExtension}`;

    // Use appropriate bucket for each file type
    let bucketName;
    let filePath;

    if (file_type_str === "pr_excel") {
      bucketName = "pr-excel-files";
      filePath = `receiving-records/${receiving_record_id_str}/${fileName}`;
    } else if (file_type_str === "original_bill") {
      bucketName = "original-bills";
      filePath = `receiving-records/${receiving_record_id_str}/${fileName}`;
    }

    console.log("📤 [File Upload] Uploading to storage:", {
      bucketName,
      filePath,
    });

    // Upload file to Supabase storage using admin client
    const { data: uploadData, error: uploadError } = await supabaseAdmin.storage
      .from(bucketName)
      .upload(filePath, file, {
        cacheControl: "3600",
        upsert: false,
      });

    if (uploadError) {
      console.error("❌ [File Upload] Storage error:", uploadError);
      return new Response(
        JSON.stringify({
          error: "Failed to upload file to storage",
          error_code: "STORAGE_ERROR",
          details: uploadError.message,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // Get the public URL for the uploaded file
    const { data: urlData } = supabaseAdmin.storage
      .from(bucketName)
      .getPublicUrl(filePath);

    const fileUrl = urlData.publicUrl;
    console.log("🔗 [File Upload] File URL generated:", fileUrl);

    // Update the receiving record with the file URL
    const updateData = {};
    if (file_type_str === "pr_excel") {
      updateData.pr_excel_file_url = fileUrl;
      updateData.pr_excel_file_uploaded = true;
    } else if (file_type_str === "original_bill") {
      updateData.original_bill_url = fileUrl;
      updateData.original_bill_uploaded = true;
    }

    const { data: dbData, error: dbError } = await supabaseAdmin
      .from("receiving_records")
      .update(updateData)
      .eq("id", receiving_record_id_str)
      .select(
        "id, pr_excel_file_url, original_bill_url, pr_excel_file_uploaded, original_bill_uploaded",
      );

    if (dbError) {
      console.error("❌ [File Upload] Database error:", dbError);
      // Try to clean up the uploaded file if database update fails
      try {
        await supabaseAdmin.storage.from(bucketName).remove([filePath]);
      } catch (cleanupError) {
        console.error("❌ [File Upload] Cleanup error:", cleanupError);
      }

      return new Response(
        JSON.stringify({
          error: "Failed to update database with file URL",
          error_code: "DATABASE_ERROR",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    console.log(
      "✅ [File Upload] Successfully uploaded and updated database:",
      dbData,
    );

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          file_url: fileUrl,
          file_path: filePath,
          file_type: file_type_str,
          receiving_record: dbData[0],
        },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("❌ [File Upload] Server error:", err);
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        error_code: "INTERNAL_ERROR",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
}
