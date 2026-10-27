import "server-only";

import { createHash, randomBytes } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import * as z from "zod/v4";
import { CREATE_SUPABASE_SERVER_CLIENT } from "@gusm/database/client";
import { CREATE_SUPABASE_SERVICE_ROLE_CLIENT } from "@gusm/database/service-role";

export const DEMO_LEASE_COOKIE_NAME = "gymu_demo_lease";
export const DEMO_MODE_ENABLED = process.env["GYMU_DEMO_MODE"] === "enabled";

const DEMO_ROLE_SCHEMA = z.enum(["student", "u_staff", "gym_staff"]);
const DEMO_BUNDLE_SCHEMA = z.object({
  bundle_key: z.string().regex(/^demo-[0-9]{2}$/),
  student_user_id: z.string().uuid(),
  u_staff_user_id: z.string().uuid(),
  gym_staff_user_id: z.string().uuid(),
});

type DemoRole = z.infer<typeof DEMO_ROLE_SCHEMA>;
type DemoBundle = z.infer<typeof DEMO_BUNDLE_SCHEMA>;

function getLeaseToken(request: NextRequest): string | null {
  const token = request.cookies.get(DEMO_LEASE_COOKIE_NAME)?.value;
  return token && /^[a-f0-9]{64}$/.test(token) ? token : null;
}

function createLeaseToken(): string {
  return randomBytes(32).toString("hex");
}

function hashLeaseToken(token: string): string {
  return `\\x${createHash("sha256").update(token).digest("hex")}`;
}

function getUserIdForRole(bundle: DemoBundle, role: DemoRole): string {
  if (role === "student") return bundle.student_user_id;
  if (role === "u_staff") return bundle.u_staff_user_id;
  return bundle.gym_staff_user_id;
}

async function getBundle(token: string, shouldClaim: boolean): Promise<DemoBundle | null> {
  const serviceRoleClient = CREATE_SUPABASE_SERVICE_ROLE_CLIENT();
  const functionName = shouldClaim ? "claim_demo_persona" : "get_demo_persona_bundle";
  const { data, error } = await serviceRoleClient.rpc(functionName, {
    p_token_hash: hashLeaseToken(token),
  });
  const parsedBundle = DEMO_BUNDLE_SCHEMA.safeParse(data?.at(0));

  if (error || !parsedBundle.success) return null;
  return parsedBundle.data;
}

async function createSessionResponse(
  request: NextRequest,
  userId: string,
  leaseToken: string,
): Promise<NextResponse | null> {
  const serviceRoleClient = CREATE_SUPABASE_SERVICE_ROLE_CLIENT();
  const { data: userResult, error: userError } =
    await serviceRoleClient.auth.admin.getUserById(userId);
  const email = userResult.user?.email;

  if (userError || !email) return null;

  const { data: linkResult, error: linkError } = await serviceRoleClient.auth.admin.generateLink({
    type: "magiclink",
    email,
  });

  if (linkError || !linkResult.properties?.hashed_token || linkResult.user?.id !== userId)
    return null;

  const response = new NextResponse(null, {
    status: 204,
    headers: {
      "Cache-Control": "no-store",
      "X-GYMU-Regulation-Acceptance-Required": "false",
    },
  });
  const sessionClient = CREATE_SUPABASE_SERVER_CLIENT({
    getAll() {
      return request.cookies.getAll();
    },
    setAll(cookiesToSet) {
      for (const cookie of cookiesToSet) {
        response.cookies.set(cookie.name, cookie.value, cookie.options);
      }
    },
  });
  const { data: sessionResult, error: sessionError } = await sessionClient.auth.verifyOtp({
    token_hash: linkResult.properties.hashed_token,
    type: "email",
  });

  if (sessionError || sessionResult.user?.id !== userId) return null;

  response.cookies.set(DEMO_LEASE_COOKIE_NAME, leaseToken, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env["NODE_ENV"] === "production",
    path: "/",
    maxAge: 8 * 60 * 60,
  });
  return response;
}

export async function createDemoLoginResponse(request: NextRequest): Promise<NextResponse | null> {
  if (!DEMO_MODE_ENABLED) return null;

  const leaseToken = getLeaseToken(request) ?? createLeaseToken();
  const bundle = await getBundle(leaseToken, true);
  if (!bundle) return null;

  return createSessionResponse(request, bundle.student_user_id, leaseToken);
}

export async function createDemoRoleSwitchResponse(
  request: NextRequest,
  role: unknown,
): Promise<NextResponse | null> {
  if (!DEMO_MODE_ENABLED) return null;

  const targetRole = DEMO_ROLE_SCHEMA.safeParse(role);
  const leaseToken = getLeaseToken(request);
  if (!targetRole.success || !leaseToken) return null;

  const response = new NextResponse();
  const sessionClient = CREATE_SUPABASE_SERVER_CLIENT({
    getAll() {
      return request.cookies.getAll();
    },
    setAll(cookiesToSet) {
      for (const cookie of cookiesToSet) {
        response.cookies.set(cookie.name, cookie.value, cookie.options);
      }
    },
  });
  const { data: claimsResult, error: claimsError } = await sessionClient.auth.getClaims();
  const currentUserId = claimsResult?.claims?.sub;
  const bundle = await getBundle(leaseToken, false);

  if (
    claimsError ||
    typeof currentUserId !== "string" ||
    !bundle ||
    ![bundle.student_user_id, bundle.u_staff_user_id, bundle.gym_staff_user_id].includes(
      currentUserId,
    )
  ) {
    return null;
  }

  return createSessionResponse(request, getUserIdForRole(bundle, targetRole.data), leaseToken);
}

export async function isDemoRequest(request: NextRequest, userId: string): Promise<boolean> {
  if (!DEMO_MODE_ENABLED) return false;

  const leaseToken = getLeaseToken(request);
  if (!leaseToken) return false;

  const bundle = await getBundle(leaseToken, false);
  return (
    bundle !== null &&
    [bundle.student_user_id, bundle.u_staff_user_id, bundle.gym_staff_user_id].includes(userId)
  );
}
