import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import {
  clearBreakSession,
  createSupabaseAuthSession,
  databaseClient,
  requireCustomerSession,
  setBreakSession,
} from "$lib/server/breakRegisterAuth";
import {
  clearEmployeeLoginFailures,
  employeeLoginLimit,
  recordEmployeeLoginFailure,
} from "$lib/server/employeeLoginRateLimit";

function clientKey(getClientAddress: () => string): string {
  try {
    return `customer:${getClientAddress().slice(0, 128)}`;
  } catch {
    return "customer:unknown-client";
  }
}

const failure = (
  message = "OTP verification failed",
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
    const customer = await requireCustomerSession(cookies);
    return json({ success: true, ...customer });
  } catch {
    return failure("Customer session required", 401);
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
      "Too many verification attempts. Please try again later.",
      429,
      limit.retryAfterSeconds,
    );

  const body = await request.json().catch(() => ({}));
  const whatsappNumber =
    typeof body.whatsappNumber === "string" ? body.whatsappNumber.trim() : "";
  const otp = typeof body.otp === "string" ? body.otp.trim() : "";
  const purpose = body.purpose === "registration" ? "registration" : "login";
  if (!/^\+9665\d{8}$/.test(whatsappNumber) || !/^\d{6}$/.test(otp)) {
    recordEmployeeLoginFailure(key);
    return failure();
  }

  try {
    const { data, error } = await databaseClient().rpc(
      "verify_customer_auth_otp",
      {
        p_whatsapp_number: whatsappNumber,
        p_otp: otp,
        p_purpose: purpose,
      },
    );
    if (error) throw error;
    if (!data?.success || !data.customer_id) {
      recordEmployeeLoginFailure(key);
      return json(
        data || { success: false, error: "OTP verification failed" },
        {
          status: 401,
        },
      );
    }

    const authSession = await createSupabaseAuthSession(
      String(data.customer_id),
      "customer",
    );
    setBreakSession(
      cookies,
      String(data.customer_id),
      url.protocol === "https:",
      "customer",
    );
    clearEmployeeLoginFailures(key);
    return json({ ...data, authSession });
  } catch (error) {
    console.error(
      "[CustomerSession] Verification failed:",
      error instanceof Error ? error.message : "Unknown error",
    );
    return failure("Authentication service unavailable", 503);
  }
};

export const DELETE: RequestHandler = async ({ cookies }) => {
  clearBreakSession(cookies, "customer");
  return json({ success: true });
};
