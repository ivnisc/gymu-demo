import { NextResponse, type NextRequest } from "next/server";
import * as z from "zod/v4";
import { CREATE_SUPABASE_SERVER_CLIENT } from "@gusm/database/client";
import { CREATE_SUPABASE_SERVICE_ROLE_CLIENT } from "@gusm/database/service-role";
import { isDemoRequest } from "@/lib/auth/demo-session";

export const runtime = "nodejs";

const CURRENT_USER_SCHEMA = z.object({
  user_name: z.string().min(1),
  role: z.enum(["student", "u_staff", "gym_staff", "admin"]),
  booking_profile_complete: z.boolean(),
  streak_weeks: z.number().int().nonnegative(),
  theme_preference: z.enum(["dark", "light"]),
});

function createResponse(response: NextResponse, status: number, body: Record<string, unknown>) {
  const result = NextResponse.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });

  for (const cookie of response.cookies.getAll()) {
    result.cookies.set(cookie.name, cookie.value, cookie);
  }

  return result;
}

async function getAuthenticatedUserId(request: NextRequest, response: NextResponse) {
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
  const { data, error } = await sessionClient.auth.getClaims();
  const userId = data?.claims.sub;

  if (error || typeof userId !== "string" || userId.length === 0) {
    return null;
  }

  return userId;
}

export async function GET(request: NextRequest) {
  const response = new NextResponse();
  const userId = await getAuthenticatedUserId(request, response);

  if (!userId) {
    return createResponse(response, 401, { code: "unauthenticated" });
  }

  const serviceRoleClient = CREATE_SUPABASE_SERVICE_ROLE_CLIENT();
  const [profileResult, appUserResult] = await Promise.all([
    serviceRoleClient.rpc("get_profile_overview", {
      p_actor_user_id: userId,
      p_target_user_id: userId,
    }),
    serviceRoleClient
      .from("app_user")
      .select("regulation_accepted_at")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);
  const currentUser = CURRENT_USER_SCHEMA.safeParse(profileResult.data?.at(0));

  if (profileResult.error || appUserResult.error || !appUserResult.data || !currentUser.success) {
    console.error("[CURRENT_USER] could not read topbar context.");
    return createResponse(response, 403, { code: "current_user_unavailable" });
  }

  return createResponse(response, 200, {
    userName: currentUser.data.user_name,
    role: currentUser.data.role,
    bookingProfileComplete: currentUser.data.booking_profile_complete,
    regulationAccepted: appUserResult.data.regulation_accepted_at !== null,
    streakWeeks: currentUser.data.streak_weeks,
    themePreference: currentUser.data.theme_preference,
    demoMode: await isDemoRequest(request, userId),
  });
}
