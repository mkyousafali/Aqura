/**
 * Warning generation utility that can work both server-side and client-side
 * depending on the deployment configuration
 */

/**
 * Generate warning using server-side API endpoint
 */
export async function generateWarningServerSide(assignment, language = "en") {
  try {
    const response = await fetch("/api/generate-warning", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        assignment,
        language,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(
        errorData.error || `HTTP ${response.status}: ${response.statusText}`,
      );
    }

    const result = await response.json();
    return result;
  } catch (error) {
    console.error("Server-side warning generation failed:", error);
    throw error;
  }
}

/**
 * Generate warning using client-side API call (fallback for static deployments)
 * Note: This should only be used if server-side API is not available
 */
export async function generateWarningClientSide(assignment, language = "en") {
  console.warn(
    "Using client-side API call - this is not recommended for production",
  );

  // This would require the API key to be exposed to the client
  // which is not secure. Only use for testing or in environments where
  // the API key can be properly secured
  throw new Error(
    "Client-side API calls are not implemented for security reasons",
  );
}

/**
 * Main warning generation function with automatic fallback
 */
export async function generateWarning(assignment, language = "en") {
  try {
    // Try server-side first
    return await generateWarningServerSide(assignment, language);
  } catch (error) {
    if (error.message.includes("404") || error.message.includes("not found")) {
      console.warn(
        "Server-side API not available, falling back to alternative method",
      );
      // In a real implementation, you would either:
      // 1. Use a serverless function service
      // 2. Use a third-party API proxy service
      // 3. Have a separate backend service
      throw new Error(
        "Warning generation service not available. Please contact administrator.",
      );
    }
    throw error;
  }
}

/**
 * Create language-specific prompts for warning generation
 */
export function createWarningPrompts() {
  return {
    english: (
      assignment,
    ) => `Generate a professional performance warning notice for an employee with poor task completion performance.

Employee Details:
- Name: ${assignment.assignedToEmployee || assignment.assignedTo}
- Assigned By: ${assignment.assignedBy}
- Assignment Type: ${assignment.assignmentType || "Task"}
- Branch: ${assignment.branch || "Not specified"}

Performance Statistics:
- Total Tasks Assigned: ${assignment.totalAssigned || 0}
- Tasks Completed: ${assignment.totalCompleted || 0}
- Overdue Tasks: ${assignment.totalOverdue || 0}
- Completion Rate: ${assignment.totalAssigned > 0 ? Math.round((assignment.totalCompleted / assignment.totalAssigned) * 100) : 0}%

Generate a formal, professional warning letter content. Do NOT include dates, names, or company placeholders.`,

    arabic: (
      assignment,
    ) => `أنشئ محتوى إشعار تحذير مهني لموظف لديه أداء ضعيف في إنجاز المهام.

تفاصيل الموظف:
- الاسم: ${assignment.assignedToEmployee || assignment.assignedTo}
- مكلف من قبل: ${assignment.assignedBy}
- نوع التكليف: ${assignment.assignmentType || "مهمة"}
- الفرع: ${assignment.branch || "غير محدد"}

إحصائيات الأداء:
- إجمالي المهام المكلفة: ${assignment.totalAssigned || 0}
- المهام المكتملة: ${assignment.totalCompleted || 0}
- المهام المتأخرة: ${assignment.totalOverdue || 0}
- معدل الإنجاز: ${assignment.totalAssigned > 0 ? Math.round((assignment.totalCompleted / assignment.totalAssigned) * 100) : 0}%

أنشئ محتوى خطاب تحذير رسمي ومهني. لا تضع تواريخ أو أسماء أو متغيرات الشركة.`,

    // Add other languages as needed...
  };
}
