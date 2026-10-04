import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import {
  clearBreakSession,
  createSupabaseAuthSession,
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
    return `cashier:${getClientAddress().slice(0, 128)}`;
  } catch {
    return "cashier:unknown-client";
  }
}

function sameOrigin(request: Request, url: URL): boolean {
  const origin = request.headers.get("origin");
  return !origin || origin === url.origin;
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
    const user = await requireBreakUser(cookies, "cashier");
    return json({ success: true, user });
  } catch {
    return failure("Cashier session required", 401);
  }
};

export const POST: RequestHandler = async ({
  request,
  cookies,
  url,
  getClientAddress,
}) => {
  if (!sameOrigin(request, url))
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
    const verifiedUser =
      !verificationError && verification?.success ? verification.user : null;
    if (!verifiedUser?.id) {
      recordEmployeeLoginFailure(key);
      return failure();
    }

    const [
      { data: permission, error: permissionError },
      { data: employee, error: employeeError },
    ] = await Promise.all([
      db
        .from("interface_permissions")
        .select("cashier_enabled")
        .eq("user_id", verifiedUser.id)
        .maybeSingle(),
      db
        .from("hr_employee_master")
        .select("name_en,name_ar,current_branch_id")
        .eq("user_id", verifiedUser.id)
        .maybeSingle(),
    ]);
    if (permissionError) throw permissionError;
    if (employeeError) throw employeeError;
    if (permission?.cashier_enabled !== true)
      return failure("Cashier access is disabled", 403);

    const authSession = await createSupabaseAuthSession(verifiedUser.id);
    setBreakSession(
      cookies,
      verifiedUser.id,
      url.protocol === "https:",
      "cashier",
    );
    clearEmployeeLoginFailures(key);
    return json({
      success: true,
      user: {
        id: verifiedUser.id,
        username: verifiedUser.username,
        employee_id: verifiedUser.employee_id,
        branch_id: employee?.current_branch_id ?? verifiedUser.branch_id,
        default_language: verifiedUser.default_language,
        name_en:
          employee?.name_en || employee?.name_ar || verifiedUser.username,
        name_ar:
          employee?.name_ar || employee?.name_en || verifiedUser.username,
        role: "Cashier",
      },
      authSession,
    });
  } catch (error) {
    console.error(
      "[CashierSession] Login failed:",
      error instanceof Error ? error.message : "Unknown error",
    );
    return failure("Authentication service unavailable", 503);
  }
};

export const PATCH: RequestHandler = async ({
  request,
  cookies,
  url,
  getClientAddress,
}) => {
  if (!sameOrigin(request, url))
    return failure("Request origin is not allowed", 403);
  try {
    const actor = await requireBreakUser(cookies, "cashier");
    const key = clientKey(getClientAddress);
    const limit = employeeLoginLimit(key);
    if (!limit.allowed)
      return failure(
        "Too many login attempts. Please try again later.",
        429,
        limit.retryAfterSeconds,
      );
    const body = await request.json().catch(() => ({}));
    const code =
      typeof body.quickAccessCode === "string"
        ? body.quickAccessCode.trim()
        : "";
    if (!/^[0-9]{6}$/.test(code)) {
      recordEmployeeLoginFailure(key);
      return failure();
    }
    const { data, error } = await databaseClient().rpc(
      "verify_quick_access_code",
      { p_code: code },
    );
    if (error || !data?.success || String(data.user?.id) !== String(actor.id)) {
      recordEmployeeLoginFailure(key);
      return failure("The access code does not match this cashier");
    }
    clearEmployeeLoginFailures(key);
    return json({ success: true });
  } catch {
    return failure("Cashier session required", 401);
  }
};

export const PUT: RequestHandler = async ({ request, cookies, url }) => {
  if (!sameOrigin(request, url))
    return failure("Request origin is not allowed", 403);
  try {
    const actor = await requireBreakUser(cookies, "cashier");
    const body = await request.json().catch(() => ({}));
    const deviceId =
      typeof body.deviceId === "string" ? body.deviceId.trim() : "";
    const deviceName =
      typeof body.deviceName === "string"
        ? body.deviceName.trim().slice(0, 200)
        : null;
    if (!deviceId || deviceId.length > 200)
      return failure("Invalid cashier device", 400);
    const { data, error } = await databaseClient().rpc(
      "claim_cashier_session",
      {
        p_user_id: actor.id,
        p_device_id: deviceId,
        p_device_name: deviceName,
        p_app_kind: "windows",
      },
    );
    if (error || !data?.success || !data?.session_token)
      throw error || new Error("Device claim failed");
    return json({ success: true, sessionToken: data.session_token });
  } catch (error) {
    console.error(
      "[CashierSession] Device claim failed:",
      error instanceof Error ? error.message : "Unknown error",
    );
    return failure("Cashier session required", 401);
  }
};

export const DELETE: RequestHandler = async ({ request, cookies, url }) => {
  if (!sameOrigin(request, url))
    return failure("Request origin is not allowed", 403);
  try {
    const actor = await requireBreakUser(cookies, "cashier");
    const body = await request.json().catch(() => ({}));
    if (typeof body.sessionToken === "string" && body.sessionToken) {
      await databaseClient().rpc("release_cashier_session", {
        p_user_id: actor.id,
        p_session_token: body.sessionToken,
      });
    }
  } catch {
    // Logout remains idempotent even if the cookie has expired.
  } finally {
    clearBreakSession(cookies, "cashier");
  }
  return json({ success: true });
};
