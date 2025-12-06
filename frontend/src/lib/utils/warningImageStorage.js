/**
 * Warning Image Storage Utility
 * Handles saving warning templates as images to Supabase Storage
 * Created: 2025-10-30
 */

import { supabase } from "./supabase";
import html2canvas from "html2canvas";

/**
 * Convert HTML element to canvas and then to blob
 * @param {HTMLElement} element - The HTML element to convert
 * @param {Object} options - html2canvas options
 * @returns {Promise<Blob>} - Image blob
 */
export async function elementToBlob(element, options = {}) {
  const defaultOptions = {
    scale: 2, // Higher quality
    useCORS: true,
    allowTaint: true,
    backgroundColor: "#ffffff",
    logging: false,
    ...options,
  };

  const canvas = await html2canvas(element, defaultOptions);

  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) {
          resolve(blob);
        } else {
          reject(new Error("Failed to convert canvas to blob"));
        }
      },
      "image/png",
      0.95, // Quality
    );
  });
}

/**
 * Generate a unique filename for the warning image
 * @param {string} warningReference - Warning reference number (e.g., WRN-20251030-0001)
 * @param {string} employeeName - Name of the warned employee
 * @param {string} employeeId - Employee ID (optional, for extra uniqueness)
 * @returns {string} - Unique filename with path
 */
export function generateWarningImagePath(
  warningReference,
  employeeName = "Unknown",
  employeeId = null,
) {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const timestamp = now.getTime();

  // Sanitize employee name for filename (remove special characters, spaces)
  const sanitizedName = employeeName
    .replace(/[^a-zA-Z0-9\s]/g, "") // Remove special chars
    .trim()
    .replace(/\s+/g, "_") // Replace spaces with underscore
    .toLowerCase();

  // Sanitize warning reference for filename
  const sanitizedRef = warningReference.replace(/[^a-zA-Z0-9-]/g, "_");

  // Build filename parts
  let filenameParts = [sanitizedName, sanitizedRef];

  // Add employee ID if provided (first 8 chars for brevity)
  if (employeeId) {
    const shortId = employeeId.substring(0, 8);
    filenameParts.push(shortId);
  }

  // Add timestamp for absolute uniqueness
  filenameParts.push(timestamp.toString());

  const filename = filenameParts.join("_") + ".png";

  // Path format: YYYY/MM/employeename_reference_id_timestamp.png
  // Example: 2025/10/john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png
  return `${year}/${month}/${filename}`;
}

/**
 * Upload warning image to Supabase Storage
 * @param {Blob} imageBlob - The image blob to upload
 * @param {string} warningReference - Warning reference number
 * @param {string} employeeName - Name of the warned employee
 * @param {string} employeeId - Employee ID (optional)
 * @returns {Promise<Object>} - Upload result with path and public URL
 */
export async function uploadWarningImage(
  imageBlob,
  warningReference,
  employeeName = "Unknown",
  employeeId = null,
) {
  try {
    // Generate unique path with employee name
    const filePath = generateWarningImagePath(
      warningReference,
      employeeName,
      employeeId,
    );

    console.log("📤 Uploading warning image for:", employeeName);
    console.log("   Path:", filePath);

    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from("warning-documents")
      .upload(filePath, imageBlob, {
        contentType: "image/png",
        cacheControl: "3600",
        upsert: false, // Don't overwrite existing files
      });

    if (error) {
      console.error("❌ Upload error:", error);
      throw error;
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from("warning-documents")
      .getPublicUrl(filePath);

    console.log("✅ Upload successful:", urlData.publicUrl);

    return {
      success: true,
      path: filePath,
      publicUrl: urlData.publicUrl,
      fullPath: data.path,
    };
  } catch (error) {
    console.error("❌ Error uploading warning image:", error);
    return {
      success: false,
      error: error.message,
    };
  }
}

/**
 * Update employee_warnings table with the image URL
 * @param {string} warningId - The warning record ID
 * @param {string} imageUrl - The public URL of the uploaded image
 * @returns {Promise<Object>} - Update result
 */
export async function updateWarningWithImageUrl(warningId, imageUrl) {
  try {
    const { data, error } = await supabase
      .from("employee_warnings")
      .update({
        warning_document_url: imageUrl,
        updated_at: new Date().toISOString(),
      })
      .eq("id", warningId)
      .select()
      .single();

    if (error) {
      console.error("❌ Error updating warning record:", error);
      throw error;
    }

    console.log("✅ Warning record updated with image URL");
    return { success: true, data };
  } catch (error) {
    console.error("❌ Error updating warning record:", error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete warning image from storage
 * @param {string} filePath - Path to the file in storage
 * @returns {Promise<Object>} - Delete result
 */
export async function deleteWarningImage(filePath) {
  try {
    // Extract path from full URL if needed
    let extractedPath = filePath;
    if (filePath.includes("warning-documents/")) {
      extractedPath = filePath.split("warning-documents/")[1];
    }

    const { data, error } = await supabase.storage
      .from("warning-documents")
      .remove([extractedPath]);

    if (error) {
      console.error("❌ Error deleting warning image:", error);
      throw error;
    }

    console.log("✅ Warning image deleted successfully");
    return { success: true, data };
  } catch (error) {
    console.error("❌ Error deleting warning image:", error);
    return { success: false, error: error.message };
  }
}

/**
 * Generate WhatsApp share URL with image
 * @param {string} imageUrl - Public URL of the warning image
 * @param {string} recipientName - Name of the recipient
 * @param {string} message - Optional custom message
 * @returns {string} - WhatsApp Web URL
 */
export function generateWhatsAppShareUrl(
  imageUrl,
  recipientName,
  message = "",
) {
  const defaultMessage = `Performance Warning Notice for ${recipientName}\n\nPlease review the attached warning document.\n\nDocument: ${imageUrl}`;

  const finalMessage = message || defaultMessage;
  const encodedMessage = encodeURIComponent(finalMessage);

  // WhatsApp Web URL (user can select recipient)
  return `https://web.whatsapp.com/send?text=${encodedMessage}`;
}

/**
 * Complete workflow: Capture, Upload, and Save
 * @param {HTMLElement} element - Element to capture
 * @param {string} warningId - Warning record ID
 * @param {string} warningReference - Warning reference number
 * @param {string} employeeName - Name of the warned employee
 * @param {string} employeeId - Employee ID (optional)
 * @returns {Promise<Object>} - Complete result with all URLs
 */
export async function captureAndSaveWarning(
  element,
  warningId,
  warningReference,
  employeeName = "Unknown",
  employeeId = null,
) {
  try {
    console.log("🎯 Starting warning capture workflow...");
    console.log("   Employee:", employeeName);
    console.log("   Reference:", warningReference);

    // Step 1: Convert element to image blob
    const imageBlob = await elementToBlob(element);
    console.log("✅ Image blob created:", imageBlob.size, "bytes");

    // Step 2: Upload to storage with employee name
    const uploadResult = await uploadWarningImage(
      imageBlob,
      warningReference,
      employeeName,
      employeeId,
    );
    if (!uploadResult.success) {
      throw new Error(uploadResult.error);
    }

    // Step 3: Update database record
    const updateResult = await updateWarningWithImageUrl(
      warningId,
      uploadResult.publicUrl,
    );
    if (!updateResult.success) {
      // Rollback: delete uploaded image
      await deleteWarningImage(uploadResult.path);
      throw new Error(updateResult.error);
    }

    console.log("🎉 Warning capture workflow completed successfully!");

    return {
      success: true,
      imageUrl: uploadResult.publicUrl,
      imagePath: uploadResult.path,
      warningId: warningId,
      warningData: updateResult.data,
    };
  } catch (error) {
    console.error("❌ Warning capture workflow failed:", error);
    return {
      success: false,
      error: error.message,
    };
  }
}
