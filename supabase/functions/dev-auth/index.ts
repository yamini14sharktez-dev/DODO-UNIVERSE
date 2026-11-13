// =============================================================================
// Edge Function: dev-auth
// Description: Secure, isolated development-only OTP authentication provider.
// Security:
//   - Fails closed in production environments.
//   - Zero client service-role exposure (service-role used exclusively here).
//   - Atomic lockout and attempt limits in PostgreSQL.
//   - Issues genuine Supabase GoTrue magic-link token hashes.
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Helper: SHA-256 hash using Web Crypto API
async function sha256(message: string): Promise<string> {
  const msgUint8 = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Helper: E.164 normalization for Indian phone numbers
function normalizeIndianPhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 10) {
    return `+91${digits}`;
  } else if (digits.length === 12 && digits.startsWith("91")) {
    return `+${digits}`;
  }
  return phone.startsWith("+") ? phone : `+${digits}`;
}

// Helper: Compare phone numbers by last 10 digits to handle leading +, country code, or GoTrue formatting
function matchesPhone(uPhone: string | null | undefined, targetPhone: string): boolean {
  if (!uPhone) return false;
  const targetDigits = targetPhone.replace(/\D/g, "");
  const uDigits = uPhone.replace(/\D/g, "");
  if (targetDigits.length >= 10 && uDigits.length >= 10) {
    return uDigits.slice(-10) === targetDigits.slice(-10);
  }
  return uDigits === targetDigits;
}

// Helper: Find auth user across all pages without hitting default 50-user limit
async function findAuthUser(
  supabaseAdmin: any,
  predicate: (user: any) => boolean
): Promise<any | null> {
  let page = 1;
  const perPage = 100;
  while (true) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({
      page,
      perPage,
    });
    if (error || !data?.users || data.users.length === 0) {
      break;
    }
    const match = data.users.find(predicate);
    if (match) {
      return match;
    }
    if (data.users.length < perPage) {
      break; // Reached last page
    }
    page++;
  }
  return null;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // 1. Production Safeguard: Strict allowlist. Fails closed if missing, empty, or unrecognized.
  const rawEnv = Deno.env.get("ENVIRONMENT");
  const environment = (rawEnv ?? "").toLowerCase().trim();
  const allowedDevEnvironments = ["development", "dev", "test"];

  if (!environment || !allowedDevEnvironments.includes(environment)) {
    return new Response(
      JSON.stringify({ error: "Endpoint not available" }),
      { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Server configuration error" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const body = await req.json();
    const action = body.action;

    // -------------------------------------------------------------------------
    // ACTION: send-mobile-otp
    // -------------------------------------------------------------------------
    if (action === "send-mobile-otp") {
      const rawMobile = body.mobile_number ?? "";
      const isLogin = body.is_login === true;
      const normalized = normalizeIndianPhone(rawMobile);

      // Validate Indian 10-digit mobile number format
      if (!/^\+91[6-9]\d{9}$/.test(normalized)) {
        return new Response(
          JSON.stringify({ error: "Please enter a valid 10-digit mobile number." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Check if number is currently disabled or locked out in dev_auth_test_numbers
      const { data: testNum } = await supabaseAdmin
        .from("dev_auth_test_numbers")
        .select("is_enabled, locked_until")
        .eq("mobile_number", normalized)
        .maybeSingle();

      if (testNum) {
        if (!testNum.is_enabled) {
          return new Response(
            JSON.stringify({ error: "This mobile number is disabled for development access." }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        if (testNum.locked_until && new Date(testNum.locked_until) > new Date()) {
          return new Response(
            JSON.stringify({ error: "Too many failed attempts. Please wait 15 minutes before trying again." }),
            { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      if (isLogin) {
        // For login requests, verify an existing account exists in auth
        const existingUser = await findAuthUser(
          supabaseAdmin,
          (u) => matchesPhone(u.phone, normalized)
        );
        if (!existingUser) {
          return new Response(
            JSON.stringify({
              error: "No existing account found with this mobile number. Please register first.",
            }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      // Allow any valid 10-digit Indian mobile number to register in development
      return new Response(
        JSON.stringify({ success: true, message: "Development OTP ready" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------------------------
    // ACTION: verify-mobile-otp
    // -------------------------------------------------------------------------
    if (action === "verify-mobile-otp") {
      const rawMobile = body.mobile_number ?? "";
      const otp = (body.otp ?? "").toString().trim();
      const fullName = (body.full_name ?? "").trim();
      const email = (body.email ?? "").trim();

      const normalized = normalizeIndianPhone(rawMobile);

      // 1. Atomic verification and lockout check via PostgreSQL function
      const { data: verifyRes, error: rpcError } = await supabaseAdmin.rpc(
        "dev_verify_mobile_otp",
        { p_mobile: normalized, p_otp: otp }
      );

      if (rpcError || !verifyRes || !verifyRes.success) {
        const errType = verifyRes?.error ?? "invalid_otp";
        let message = "Invalid OTP code. Please enter the correct code.";
        let status = 400;

        if (errType === "locked") {
          message = "Too many failed attempts. Account locked for 15 minutes.";
          status = 429;
        } else if (errType === "disabled" || errType === "not_found") {
          message = "Unauthorized test mobile number.";
        } else if (errType === "invalid_mobile") {
          message = verifyRes?.message ?? "Please enter a valid 10-digit mobile number.";
        }

        return new Response(
          JSON.stringify({ error: message }),
          { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 2. User provisioning in auth.users (phone confirmed, email UNCONFIRMED)
      let authUserId: string;

      // Check if user already exists across all pages
      const normalizedEmail = email.toLowerCase().trim();
      const existingUser = await findAuthUser(
        supabaseAdmin,
        (u) =>
          matchesPhone(u.phone, normalized) ||
          (normalizedEmail.length > 0 &&
            u.email?.toLowerCase().trim() === normalizedEmail)
      );

      if (existingUser) {
        // If user already completed registration
        const { data: profile } = await supabaseAdmin
          .from("profiles")
          .select("is_registration_complete")
          .eq("id", existingUser.id)
          .maybeSingle();

        if (profile?.is_registration_complete) {
          return new Response(
            JSON.stringify({ error: "An account with this mobile number or email already exists. Please login." }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        authUserId = existingUser.id;
        // Update uncompleted user details
        await supabaseAdmin.auth.admin.updateUserById(authUserId, {
          phone_confirm: true,
          email: email || existingUser.email,
          user_metadata: { full_name: fullName || existingUser.user_metadata?.full_name },
        });
      } else {
        // Create new user with confirmed phone, but unconfirmed email
        const { data: created, error: createError } = await supabaseAdmin.auth.admin.createUser({
          phone: normalized,
          phone_confirm: true,
          email: email || undefined,
          email_confirm: false,
          user_metadata: {
            full_name: fullName,
            registration_completed: false,
          },
        });

        if (createError || !created.user) {
          return new Response(
            JSON.stringify({ error: createError?.message ?? "Failed to create user account" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        authUserId = created.user.id;
      }

      // 3. Generate single-use, cryptographically secure registration token
      const rawRegistrationToken = `${crypto.randomUUID().replace(/-/g, "")}${crypto.randomUUID().replace(/-/g, "")}`;
      const tokenHash = await sha256(rawRegistrationToken);

      // Default development email OTP is 123456
      const defaultEmailOtp = "123456";

      // 4. Store pending registration in PostgreSQL with robust error handling
      const { data: createPendingRes, error: createPendingError } =
        await supabaseAdmin.rpc("dev_create_pending_registration", {
          p_auth_user_id: authUserId,
          p_mobile: normalized,
          p_email: email,
          p_full_name: fullName,
          p_token_hash: tokenHash,
          p_email_otp: defaultEmailOtp,
        });

      if (createPendingError || !createPendingRes?.success) {
        console.error(
          "dev_create_pending_registration failed:",
          createPendingError?.message ?? createPendingRes?.error ?? "unknown error"
        );
        return new Response(
          JSON.stringify({
            error: "Failed to initiate verification session. Please try again.",
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          mobile_verified: true,
          registration_token: rawRegistrationToken,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------------------------
    // ACTION: verify-email-otp
    // -------------------------------------------------------------------------
    if (action === "verify-email-otp") {
      const email = (body.email ?? "").trim();
      const otp = (body.otp ?? "").toString().trim();
      const rawToken = (body.registration_token ?? "").trim();

      if (!rawToken || !email || !otp) {
        return new Response(
          JSON.stringify({ error: "Missing required verification fields." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const tokenHash = await sha256(rawToken);

      // If pending registration was created with an empty email, update it with the provided email
      const { data: pendingRecord } = await supabaseAdmin
        .from("dev_auth_pending_registrations")
        .select("id, email, auth_user_id")
        .eq("registration_token_hash", tokenHash)
        .maybeSingle();

      if (pendingRecord && (!pendingRecord.email || pendingRecord.email.trim() === "")) {
        await supabaseAdmin
          .from("dev_auth_pending_registrations")
          .update({ email: email, updated_at: new Date().toISOString() })
          .eq("id", pendingRecord.id);

        if (pendingRecord.auth_user_id) {
          await supabaseAdmin.auth.admin.updateUserById(pendingRecord.auth_user_id, {
            email: email,
          });
        }
      }

      // 1. Atomic verification in PostgreSQL (checks token, email, attempts, and expiry)
      const { data: emailRes, error: rpcError } = await supabaseAdmin.rpc(
        "dev_verify_email_otp",
        {
          p_token_hash: tokenHash,
          p_email: email,
          p_otp: otp,
        }
      );

      if (rpcError || !emailRes || !emailRes.success) {
        const errType = emailRes?.error ?? "invalid";
        let message = "Invalid or expired OTP. Please try again.";
        if (errType === "expired") {
          message = "Registration session has expired. Please restart registration.";
        }
        return new Response(
          JSON.stringify({ error: message }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const authUserId = emailRes.auth_user_id;

      // 2. Mark email confirmed in auth.users
      await supabaseAdmin.auth.admin.updateUserById(authUserId, {
        email_confirm: true,
        user_metadata: { registration_completed: true },
      });

      // 3. Issue genuine Supabase session via magic-link token exchange
      const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
        type: "magiclink",
        email: email,
      });

      if (linkError || !linkData?.properties?.hashed_token) {
        return new Response(
          JSON.stringify({ error: "Failed to issue authenticated session." }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          email_verified: true,
          token_hash: linkData.properties.hashed_token,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------------------------
    // ACTION: login
    // -------------------------------------------------------------------------
    if (action === "login") {
      const rawMobile = body.mobile_number ?? "";
      const otp = (body.otp ?? "").toString().trim();
      const normalized = normalizeIndianPhone(rawMobile);

      // 1. Atomic mobile OTP verification
      const { data: verifyRes, error: rpcError } = await supabaseAdmin.rpc(
        "dev_verify_mobile_otp",
        { p_mobile: normalized, p_otp: otp }
      );

      if (rpcError || !verifyRes || !verifyRes.success) {
        const errType = verifyRes?.error ?? "invalid_otp";
        let message = "Invalid verification code or mobile number.";
        let status = 400;

        if (errType === "locked") {
          message = "Too many failed attempts. Account locked for 15 minutes.";
          status = 429;
        }

        return new Response(
          JSON.stringify({ error: message }),
          { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 2. Lookup existing user by phone across all pages
      const existingUser = await findAuthUser(
        supabaseAdmin,
        (u) => matchesPhone(u.phone, normalized)
      );

      if (!existingUser || !existingUser.email) {
        return new Response(
          JSON.stringify({ error: "No existing account found with this mobile number. Please register first." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 3. Verify trusted registration completion in public.profiles
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("is_registration_complete")
        .eq("id", existingUser.id)
        .maybeSingle();

      if (!profile?.is_registration_complete) {
        return new Response(
          JSON.stringify({ error: "Registration is incomplete for this account. Please complete registration." }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 4. Generate genuine session token hash
      const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
        type: "magiclink",
        email: existingUser.email,
      });

      if (linkError || !linkData?.properties?.hashed_token) {
        return new Response(
          JSON.stringify({ error: "Unable to establish login session." }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          token_hash: linkData.properties.hashed_token,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Unknown action" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("dev-auth caught exception:", error);
    return new Response(
      JSON.stringify({
        error: "An unexpected error occurred during authentication.",
        details: error?.message ?? String(error),
        stack: error?.stack,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

