import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import {
  requireBreakUser,
} from "$lib/server/breakRegisterAuth";
import { runEmployeeSessionFlow } from "$lib/server/employeeSessionFlow";
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
    const user = await requireBreakUser(cookies, "mobile");
    return json({ success: true, user });
  } catch {
    return failure("Mobile session required", 401);
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
  try {
    const result = await runEmployeeSessionFlow({ interfaceType: "mobile", body, cookies, secure: url.protocol === "https:" });
    if (result.status === 401) {
      recordEmployeeLoginFailure(key);
    }
    if (result.status === 200 && result.body.success === true && !result.body.otpRequired) clearEmployeeLoginFailures(key);
    return json(result.body, { status: result.status });
  } catch (error) {
    console.error(
      "[MobileSession] Login failed:",
      error instanceof Error ? error.message : "Unknown error",
    );
    return failure("Authentication service unavailable", 503);
  }
};
