import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { env } from "$env/dynamic/private";
import { createClient } from "@supabase/supabase-js";
import type { Cookies } from "@sveltejs/kit";

type InterfaceKind = "desktop" | "mobile" | "cashier" | "customer";
const cookieName = (kind: InterfaceKind) => `aqura_break_access_${kind}`;
const lifetimeSeconds = 30 * 24 * 60 * 60;

function secret(): string {
  if (!env.JWT_SECRET)
    throw new Error("Break Register session signing is not configured");
  return env.JWT_SECRET;
}

export function databaseClient() {
  const url = env.VITE_SUPABASE_URL;
  const key = env.VITE_SUPABASE_SERVICE_KEY;
  if (!url || !key)
    throw new Error("Break Register database access is not configured");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function createSupabaseAuthSession(
  subjectId: string,
  subject: "employee" | "customer" = "employee",
): Promise<{
  access_token: string;
  refresh_token: string;
}> {
  const url = env.VITE_SUPABASE_URL;
  const anonKey = env.VITE_SUPABASE_ANON_KEY;
  if (!url || !anonKey)
    throw new Error("Supabase Auth session creation is not configured");

  const admin = databaseClient();
  const existingAuthUser = await admin.auth.admin.getUserById(subjectId);
  const email =
    existingAuthUser.data.user?.email ||
    `${subject === "customer" ? "customer" : "desktop"}-${subjectId}@auth.aqura.invalid`;

  const { data: link, error: linkError } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
    options: {
      data:
        subject === "customer"
          ? { aqura_customer_id: subjectId, aqura_subject: subject }
          : { aqura_user_id: subjectId, aqura_subject: subject },
    },
  });
  if (linkError || !link.user?.id || !link.properties?.hashed_token)
    throw linkError || new Error("Could not create Supabase Auth identity");

  const appMetadata =
    subject === "customer"
      ? {
          role: "customer_authenticated",
          aqura_customer_id: subjectId,
          aqura_subject: subject,
        }
      : {
          role: "authenticated",
          aqura_user_id: subjectId,
          aqura_subject: subject,
        };
  const { error: metadataError } = await admin.auth.admin.updateUserById(
    link.user.id,
    { app_metadata: appMetadata },
  );
  if (metadataError) throw metadataError;

  const { data: mappedUser, error: mappingError } = await admin
    .from(subject === "customer" ? "customers" : "users")
    .update({ auth_user_id: link.user.id })
    .eq("id", subjectId)
    .or(`auth_user_id.is.null,auth_user_id.eq.${link.user.id}`)
    .select("auth_user_id")
    .single();
  const mappingColumnMissing =
    mappingError?.code === "PGRST204" || mappingError?.code === "42703";
  if (
    !mappingColumnMissing &&
    (mappingError || mappedUser?.auth_user_id !== link.user.id)
  )
    throw mappingError || new Error("Supabase Auth identity mapping conflict");

  const authClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: verified, error: verifyError } =
    await authClient.auth.verifyOtp({
      token_hash: link.properties.hashed_token,
      type: "email",
    });
  if (
    verifyError ||
    !verified.session?.access_token ||
    !verified.session.refresh_token
  )
    throw verifyError || new Error("Could not establish Supabase Auth session");

  return {
    access_token: verified.session.access_token,
    refresh_token: verified.session.refresh_token,
  };
}

function readSession(
  cookies: Cookies,
  kind: InterfaceKind,
): { id: string; allowed: string[]; expires: number } | null {
  const token = cookies.get(cookieName(kind));
  if (!token) return null;
  const [payload, signature] = token.split(".");
  if (!payload || !signature) return null;
  const expected = createHmac("sha256", secret()).update(payload).digest();
  const actual = Buffer.from(signature, "base64url");
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected))
    return null;
  let decoded: any;
  try {
    decoded = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
  } catch {
    return null;
  }
  if (
    !decoded.id ||
    !Number.isFinite(decoded.expires) ||
    decoded.expires < Date.now()
  )
    return null;
  return {
    id: decoded.id,
    allowed: Array.isArray(decoded.allowed) ? decoded.allowed : [decoded.id],
    expires: decoded.expires,
  };
}

function writeSession(
  cookies: Cookies,
  userId: string,
  allowed: string[],
  secure: boolean,
  kind: InterfaceKind,
): void {
  const payload = Buffer.from(
    JSON.stringify({
      id: userId,
      allowed,
      expires: Date.now() + lifetimeSeconds * 1000,
      nonce: randomBytes(16).toString("hex"),
    }),
  ).toString("base64url");
  const signature = createHmac("sha256", secret())
    .update(payload)
    .digest("base64url");
  cookies.set(cookieName(kind), `${payload}.${signature}`, {
    path: "/",
    httpOnly: true,
    sameSite: "strict",
    secure,
    maxAge: lifetimeSeconds,
  });
}

export function setBreakSession(
  cookies: Cookies,
  userId: string,
  secure: boolean,
  kind: InterfaceKind,
): void {
  const allowed = new Set(readSession(cookies, kind)?.allowed || []);
  allowed.add(userId);
  writeSession(cookies, userId, [...allowed], secure, kind);
}

export function switchBreakSession(
  cookies: Cookies,
  userId: string,
  secure: boolean,
  kind: InterfaceKind,
): boolean {
  const session = readSession(cookies, kind);
  if (!session?.allowed.includes(userId)) return false;
  writeSession(cookies, userId, session.allowed, secure, kind);
  return true;
}

export function clearBreakSession(cookies: Cookies, kind: InterfaceKind): void {
  cookies.delete(cookieName(kind), { path: "/" });
}

export async function requireBreakUser(
  cookies: Cookies,
  kind: InterfaceKind,
): Promise<{ id: string; isMasterAdmin: boolean; isAdmin: boolean }> {
  const session = readSession(cookies, kind);
  if (!session) throw new Error("Break Register session required");
  const { data, error } = await databaseClient()
    .from("users")
    .select("id, status, is_master_admin, is_admin")
    .eq("id", session.id)
    .single();
  if (error || !data || data.status !== "active")
    throw new Error("Break Register session is inactive");
  const { data: interfacePermission, error: permissionError } =
    await databaseClient()
      .from("interface_permissions")
      .select("desktop_enabled,mobile_enabled,cashier_enabled")
      .eq("user_id", session.id)
      .maybeSingle();
  if (
    permissionError ||
    (interfacePermission && interfacePermission[`${kind}_enabled`] === false)
  )
    throw new Error("Interface access denied");
  return {
    id: data.id,
    isMasterAdmin: data.is_master_admin === true,
    isAdmin: data.is_admin === true,
  };
}

export async function requireCustomerSession(cookies: Cookies): Promise<{
  customer_id: string;
  customer_name: string;
  whatsapp_number: string;
  registration_status: string;
}> {
  const session = readSession(cookies, "customer");
  if (!session) throw new Error("Customer session required");
  const { data, error } = await databaseClient()
    .from("customers")
    .select("id,name,whatsapp_number,registration_status")
    .eq("id", session.id)
    .single();
  if (error || !data || data.registration_status !== "approved")
    throw new Error("Customer session is inactive");
  return {
    customer_id: data.id,
    customer_name: data.name,
    whatsapp_number: data.whatsapp_number,
    registration_status: data.registration_status,
  };
}
