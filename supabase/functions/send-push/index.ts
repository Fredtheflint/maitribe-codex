import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.49.8";

type PushRequestBody = {
  userId: string;
  subscription: {
    endpoint: string;
    expirationTime?: number | null;
    keys?: {
      p256dh?: string;
      auth?: string;
    };
  };
  title: string;
  body: string;
  data?: Record<string, unknown>;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

function json(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders
    }
  });
}

function isSubscriptionExpired(err: unknown): boolean {
  if (!err || typeof err !== "object") return false;
  const maybe = err as { statusCode?: number; status?: number; body?: string };
  const code = maybe.statusCode ?? maybe.status;
  if (code === 404 || code === 410) return true;

  if (typeof maybe.body === "string") {
    const text = maybe.body.toLowerCase();
    return text.includes("expired") || text.includes("unsubscribed") || text.includes("invalid subscription");
  }

  return false;
}

function getBearerToken(req: Request): string {
  const auth = req.headers.get("Authorization") || "";
  if (!auth.toLowerCase().startsWith("bearer ")) return "";
  return auth.slice(7).trim();
}

function isServiceRoleRequest(req: Request, serviceRoleKey: string | null): boolean {
  if (!serviceRoleKey) return false;
  const authToken = getBearerToken(req);
  const apiKey = req.headers.get("apikey") || "";
  return authToken === serviceRoleKey || apiKey === serviceRoleKey;
}

async function authenticateRequest(req: Request, userId: string) {
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (isServiceRoleRequest(req, serviceRoleKey)) {
    return { ok: true as const, mode: "service_role" as const };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const accessToken = getBearerToken(req);

  if (!supabaseUrl || !supabaseAnonKey || !accessToken) {
    return { ok: false as const, status: 401, error: "Unauthorized" };
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) {
    return { ok: false as const, status: 401, error: "Invalid auth token" };
  }

  if (data.user.id !== userId) {
    return { ok: false as const, status: 403, error: "Forbidden" };
  }

  return { ok: true as const, mode: "user" as const };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { ok: false, error: "Method not allowed" });
  }

  const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY");
  const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY");
  const vapidSubject = Deno.env.get("VAPID_SUBJECT");

  if (!vapidPublicKey || !vapidPrivateKey || !vapidSubject) {
    return json(500, {
      ok: false,
      error: "Missing VAPID environment variables",
      required: ["VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY", "VAPID_SUBJECT"]
    });
  }

  let body: PushRequestBody;

  try {
    body = (await req.json()) as PushRequestBody;
  } catch {
    return json(400, { ok: false, error: "Invalid JSON body" });
  }

  if (!body?.userId || !body?.subscription?.endpoint || !body?.title || !body?.body) {
    return json(400, {
      ok: false,
      error: "Missing required fields",
      required: ["userId", "subscription", "title", "body"]
    });
  }

  if (!body.subscription.keys?.p256dh || !body.subscription.keys?.auth) {
    return json(400, {
      ok: false,
      error: "Invalid subscription keys",
      required: ["subscription.keys.p256dh", "subscription.keys.auth"]
    });
  }

  const authResult = await authenticateRequest(req, body.userId);
  if (!authResult.ok) {
    return json(authResult.status, {
      ok: false,
      error: authResult.error,
    });
  }

  webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

  const payload = JSON.stringify({
    title: body.title,
    body: body.body,
    data: body.data ?? {}
  });

  try {
    const result = await webpush.sendNotification(body.subscription, payload, {
      TTL: 300,
      urgency: "normal"
    });

    return json(200, {
      ok: true,
      userId: body.userId,
      statusCode: result.statusCode,
      endpoint: body.subscription.endpoint
    });
  } catch (err) {
    console.error("send-push error", err);

    if (isSubscriptionExpired(err)) {
      return json(410, {
        ok: false,
        userId: body.userId,
        error: "Subscription expired",
        code: "subscription_expired"
      });
    }

    return json(500, {
      ok: false,
      userId: body.userId,
      error: "Failed to send push notification"
    });
  }
});
