import { createClient } from "npm:@supabase/supabase-js@2.95.0";

const allowedOrigins = new Set([
  "https://alpha.propertyosuk.com",
  "https://propertyosuk.com",
]);

function reply(origin: string | null, status: number, body: unknown) {
  const headers: Record<string, string> = {
    "content-type": "application/json",
    "cache-control": "no-store",
  };
  if (origin && allowedOrigins.has(origin)) {
    headers["access-control-allow-origin"] = origin;
    headers["access-control-allow-headers"] =
      "authorization, x-client-info, apikey, content-type";
    headers["access-control-allow-methods"] = "POST, OPTIONS";
    headers.vary = "Origin";
  }
  return new Response(status === 204 ? null : JSON.stringify(body), {
    status,
    headers,
  });
}

function secretKey() {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) return JSON.parse(modern).default as string;
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

function publishableKey() {
  const modern = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (modern) return JSON.parse(modern).default as string;
  return Deno.env.get("SUPABASE_ANON_KEY") ?? "";
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return reply(origin, 204, null);
  if (request.method !== "POST") {
    return reply(origin, 405, { error: "method_not_allowed" });
  }
  if (origin && !allowedOrigins.has(origin)) {
    return reply(origin, 403, { error: "origin_not_allowed" });
  }

  const authHeader = request.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return reply(origin, 401, { error: "authentication_required" });
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return reply(origin, 400, { error: "invalid_json" });
  }
  if (
    typeof body.organisationId !== "string" || typeof body.email !== "string" ||
    !["admin", "member", "viewer"].includes(String(body.role))
  ) {
    return reply(origin, 400, { error: "invalid_invitation" });
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const userClient = createClient(url, publishableKey(), {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: invitationId, error: permissionError } = await userClient.rpc(
    "create_organisation_invitation",
    {
      target_organisation_id: body.organisationId,
      invited_email: body.email,
      invited_role: body.role,
    },
  );
  if (permissionError) {
    return reply(origin, permissionError.code === "42501" ? 403 : 409, {
      error: permissionError.message,
    });
  }

  const admin = createClient(url, secretKey(), {
    auth: { persistSession: false },
  });
  const redirectTo = `${origin ?? "https://alpha.propertyosuk.com"}/`;
  const { error: inviteError } = await admin.auth.admin.inviteUserByEmail(
    String(body.email).trim().toLowerCase(),
    {
      redirectTo,
      data: { propertyos_invitation_onboarding: true },
    },
  );
  if (inviteError) {
    if (
      inviteError.status === 429 ||
      inviteError.code === "over_email_send_rate_limit"
    ) {
      await admin.from("organisation_invitations").update({ state: "failed" })
        .eq("id", invitationId);
      return reply(origin, 429, {
        error: "email_rate_limit_reached",
        invitationId,
      });
    }
    const { error: existingUserEmailError } = await userClient.auth
      .signInWithOtp({
        email: String(body.email).trim().toLowerCase(),
        options: { shouldCreateUser: false, emailRedirectTo: redirectTo },
      });
    if (existingUserEmailError) {
      await admin.from("organisation_invitations").update({ state: "failed" })
        .eq("id", invitationId);
      return reply(origin, 409, {
        error: "invitation_email_failed",
        invitationId,
      });
    }
  }
  return reply(origin, 200, { invitationId });
});
