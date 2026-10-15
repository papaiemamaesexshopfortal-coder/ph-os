import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const allowedOrigins = new Set([
  "https://ph-os-kappa.vercel.app",
  "https://ph-service-fortal.vercel.app",
]);
const corsHeaders = (origin: string) => ({
  "Access-Control-Allow-Origin": origin,
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
});
const response = (body: unknown, status: number, origin: string) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders(origin), "Content-Type": "application/json", "Cache-Control": "no-store" },
});

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin") ?? "";
  const localDev = /^http:\/\/localhost:\d+$/.test(origin) || /^http:\/\/127\.0\.0\.1:\d+$/.test(origin);
  if (!allowedOrigins.has(origin) && !localDev) return new Response("Forbidden", { status: 403 });
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(origin) });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405, origin);
  const length = Number(req.headers.get("content-length") ?? 0);
  if (length > 4096) return response({ error: "Invalid request" }, 413, origin);
  try {
    const input = await req.json();
    const token = typeof input?.token === "string" ? input.token : "";
    if (token.length < 64 || token.length > 256 || !/^[a-f0-9]+$/i.test(token)) {
      return response({ error: "Invalid or expired link" }, 400, origin);
    }
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) return response({ error: "Service unavailable" }, 503, origin);
    const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    if (input.action === "get") {
      const { data, error } = await admin.rpc("get_public_quote", { p_token: token });
      if (error || !data) return response({ error: "Invalid or expired link" }, 404, origin);
      return response(data, 200, origin);
    }
    if (input.action === "decide") {
      const name = typeof input.name === "string" ? input.name.trim() : "";
      const outcome = input.outcome;
      const accepted = input.accepted === true;
      if (name.length < 2 || name.length > 160 || !["approved", "declined", "change_requested"].includes(outcome)) {
        return response({ error: "Invalid response" }, 400, origin);
      }
      const audit = {
        user_agent: (req.headers.get("user-agent") ?? "").slice(0, 300),
        language: (req.headers.get("accept-language") ?? "").slice(0, 20),
      };
      const { data, error } = await admin.rpc("submit_public_quote_decision", {
        p_token: token, p_approver_name: name, p_outcome: outcome,
        p_accepted_conditions: accepted, p_audit: audit,
      });
      if (error || !data) return response({ error: "The link is invalid, expired, or already answered" }, 409, origin);
      return response(data, 200, origin);
    }
    return response({ error: "Invalid request" }, 400, origin);
  } catch {
    return response({ error: "Invalid request" }, 400, origin);
  }
});
