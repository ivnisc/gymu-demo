import { NextResponse, type NextRequest } from "next/server";
import { CREATE_SUPABASE_SERVER_CLIENT } from "@gusm/database/client";

export const runtime = "nodejs";

function createErrorResponse(status: number) {
  return NextResponse.json(
    { code: "terms_acceptance_failed" },
    {
      status,
      headers: { "Cache-Control": "no-store" },
    },
  );
}

function getForwardedOrigin(request: NextRequest) {
  const forwardedHost = request.headers.get("x-forwarded-host")?.split(",")[0]?.trim();
  const forwardedProtocol = request.headers.get("x-forwarded-proto")?.split(",")[0]?.trim();

  if (!forwardedHost || (forwardedProtocol !== "http" && forwardedProtocol !== "https")) {
    return null;
  }

  try {
    return new URL(`${forwardedProtocol}://${forwardedHost}`).origin;
  } catch {
    return null;
  }
}

function isSameOrigin(request: NextRequest) {
  const origin = request.headers.get("origin");
  const requestOrigin = getForwardedOrigin(request) ?? request.nextUrl.origin;

  return !origin || origin === requestOrigin;
}

function isRegulationAcceptanceRequest(payload: unknown) {
  return (
    typeof payload === "object" &&
    payload !== null &&
    "acceptRegulation" in payload &&
    payload.acceptRegulation === true
  );
}

export async function POST(request: NextRequest) {
  if (!isSameOrigin(request)) {
    return createErrorResponse(403);
  }

  let payload: unknown;

  try {
    payload = await request.json();
  } catch {
    return createErrorResponse(400);
  }

  if (!isRegulationAcceptanceRequest(payload)) {
    return createErrorResponse(400);
  }

  const response = new NextResponse(null, {
    status: 204,
    headers: { "Cache-Control": "no-store" },
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
  const { data: claimsData, error: claimsError } = await sessionClient.auth.getClaims();
  const userId = claimsData?.claims.sub;

  if (claimsError || !userId) {
    return createErrorResponse(401);
  }

  const { error } = await sessionClient.rpc("accept_regulation");

  if (error) {
    console.error("[REGULATION] could not record regulation acceptance.");
    return createErrorResponse(403);
  }

  return response;
}
