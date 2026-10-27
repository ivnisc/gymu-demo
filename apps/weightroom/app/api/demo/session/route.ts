import { NextResponse, type NextRequest } from "next/server";
import * as z from "zod/v4";
import { DEMO_MODE_ENABLED, createDemoRoleSwitchResponse } from "@/lib/auth/demo-session";

export const runtime = "nodejs";

const ROLE_SWITCH_SCHEMA = z.object({
  role: z.enum(["student", "u_staff", "gym_staff"]),
});

function createResponse(status: number, body: Record<string, unknown>) {
  return NextResponse.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

export function GET() {
  return createResponse(200, { enabled: DEMO_MODE_ENABLED });
}

export async function POST(request: NextRequest) {
  if (!DEMO_MODE_ENABLED) return createResponse(404, { code: "not_found" });

  const payload: unknown = await request.json().catch(function ignoreInvalidPayload() {
    return null;
  });
  const parsedPayload = ROLE_SWITCH_SCHEMA.safeParse(payload);
  if (!parsedPayload.success) return createResponse(400, { code: "invalid_request" });

  const response = await createDemoRoleSwitchResponse(request, parsedPayload.data.role);
  if (!response) return createResponse(401, { code: "demo_session_unavailable" });
  return response;
}
