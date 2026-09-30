import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import {
  databaseClient,
  requireBreakUser,
  setBreakSession,
} from "$lib/server/breakRegisterAuth";
import {
  clearEmployeeLoginFailures,
  employeeLoginLimit,
  recordEmployeeLoginFailure,
} from "$lib/server/employeeLoginRateLimit";

function clientKey(getClientAddress: () => string): string {
  try {
    return getClientAddress().slice(0, 128);
  } catch {
    return "unknown-client";
  }
}

const failure = (
  message = "Invalid access code",
  status = 401,
  retryAfterSeconds = 0,
) =>
  json(
    { success: false, error: message },
    {
      status,
      headers:
        retryAfterSeconds > 0
          ? { "Retry-After": String(retryAfterSeconds) }
          : undefined,
    },
  );

export const GET: RequestHandler = async ({ cookies }) => {
  try {
    const user = await requireBreakUser(cookies, "desktop");
    return json({ success: true, user });
  } catch {
    return failure("Desktop session required", 401);
  }
};

export const POST: RequestHandler = async ({
  request,
  cookies,
  url,
  getClientAddress,
}) => {
  const origin = request.headers.get("origin");
  if (origin && origin !== url.origin)
    return failure("Request origin is not allowed", 403);

  const key = clientKey(getClientAddress);
  const limit = employeeLoginLimit(key);
  if (!limit.allowed)
    return failure(
      "Too many login attempts. Please try again later.",
      429,
      limit.retryAfterSeconds,
    );

  const body = await request.json().catch(() => ({}));
  const quickAccessCode =
    typeof body.quickAccessCode === "string" ? body.quickAccessCode.trim() : "";
  if (!/^[0-9]{6}$/.test(quickAccessCode)) {
    recordEmployeeLoginFailure(key);
    return failure();
  }

  try {
    const db = databaseClient();
    const { data: verification, error: verificationError } = await db.rpc(
      "verify_quick_access_code",
      { p_code: quickAccessCode },
    );
    const userId =
      !verificationError && verification?.success
        ? verification.user?.id
        : undefined;
    if (!userId) {
      recordEmployeeLoginFailure(key);
      return failure();
    }

    const [
      { data: userDetails, error: userError },
      { data: interfacePermission, error: permissionError },
    ] = await Promise.all([
      db
        .from("user_management_view")
        .select(
          "id,username,is_master_admin,is_admin,employee_name,branch_name,employee_id,branch_id,default_language,status",
        )
        .eq("id", userId)
        .single(),
      db
        .from("interface_permissions")
        .select("desktop_enabled")
        .eq("user_id", userId)
        .maybeSingle(),
    ]);

    if (userError) throw userError;
    if (!userDetails || userDetails.status !== "active")
      return failure("User account is inactive", 403);
    if (permissionError) throw permissionError;
    if (interfacePermission?.desktop_enabled === false)
      return failure("Desktop interface access is disabled", 403);

    setBreakSession(cookies, userId, url.protocol === "https:", "desktop");
    clearEmployeeLoginFailures(key);
    return json({
      success: true,
      user: {
        id: userDetails.id,
        username: userDetails.username,
        is_master_admin: userDetails.is_master_admin === true,
        is_admin: userDetails.is_admin === true,
        user_type: verification.user?.user_type,
      },
      userDetails: {
        ...userDetails,
        user_type: verification.user?.user_type,
        avatar: verification.user?.avatar,
      },
    });
  } catch (error) {
    console.error(
      "[EmployeeSession] Login failed:",
      error instanceof Error ? error.message : "Unknown error",
    );
    return failure("Authentication service unavailable", 503);
  }
};
