import { createClient } from "jsr:@supabase/supabase-js@2";

type GenerateIdentityRequest = {
  userId: string;
  answers: string[];
  language?: string;
};

type UserRow = {
  id: string;
  display_name: string | null;
  name: string | null;
  language: string | null;
};

type CheckinRow = {
  body: number;
  mind: number;
  soul: number;
  energy: number;
  note: string | null;
  created_at: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
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

function sanitizeIdentityText(text: string): string {
  const noBullets = text
    .split("\n")
    .map((line) => line.replace(/^\s*[-*•\d.)]+\s*/g, "").trim())
    .filter(Boolean)
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();

  const words = noBullets.split(/\s+/).filter(Boolean);
  if (words.length <= 80) return noBullets;
  return `${words.slice(0, 80).join(" ")}.`;
}

function splitSentences(text: string): string[] {
  return text
    .split(/(?<=[.!?])\s+/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function fallbackIdentity(answers: string[], language: string): string {
  const answerSeed = answers.filter(Boolean).slice(0, 2).join(" ").trim();

  if (language === "de") {
    const base = "Du darfst deinen Weg ruhig und echt gehen. Dein Koerper, dein Herz und dein Kopf geben dir bereits Richtung. Heute zaehlt nicht Perfektion, sondern ein ehrlicher Schritt, der sich fuer dich wahr anfuehlt.";
    return sanitizeIdentityText(answerSeed ? `${base} ${answerSeed}` : base);
  }

  const base = "You are allowed to move through life in a calm and honest way. Your body, mind, and heart already carry useful signals. Today does not require perfection, just one real step that feels true to you.";
  return sanitizeIdentityText(answerSeed ? `${base} ${answerSeed}` : base);
}

function buildMaiSystemPrompt(language: string): string {
  const languageName = language === "de" ? "German" : "English";
  const duRule = language === "de"
    ? "Address the user as 'du'. Use natural, warm German."
    : "Address the user directly as 'you'.";

  const philosophicalBase = [
    "Your guidance is rooted in three quiet pillars:",
    "1) Observer awareness (thoughts and emotions are experiences, not identity).",
    "2) Present-moment grounding (return to body and now).",
    "3) Meaningful agency (one value-aligned next step)."
  ].join(" ");

  return [
    "You are Mai, a calm and emotionally intelligent wellness companion.",
    philosophicalBase,
    "Write one short identity reflection for the user.",
    "Tone: warm, grounded, clear, never clinical, never preachy.",
    "Format: plain text only, no bullet points, no numbering, no markdown.",
    "Length: under 80 words.",
    "Include body, mind, and emotional truth in a holistic way.",
    "End with a gentle, empowering sentence.",
    duRule,
    `Always respond in ${languageName}.`
  ].join(" ");
}

function buildIdentityPrompt(userName: string, answers: string[], checkins: CheckinRow[], language: string): string {
  const safeAnswers = [0, 1, 2, 3].map((idx) => answers[idx] || "");

  const latest = checkins[0]
    ? `Latest check-in -> Body ${checkins[0].body}/10, Mind ${checkins[0].mind}/10, Soul ${checkins[0].soul}/10, Energy ${checkins[0].energy}/10${checkins[0].note ? `, Note: ${checkins[0].note}` : ""}.`
    : "No recent check-in available.";

  const languageHint = language === "de"
    ? "Schreibe in natuerlichem Deutsch und in du-Form."
    : "Write in natural English and address the user directly.";

  return [
    `User name: ${userName}`,
    "Identity onboarding answers:",
    `1) Dream life vision: ${safeAnswers[0]}`,
    `2) What matters most: ${safeAnswers[1]}`,
    `3) Desired feeling: ${safeAnswers[2]}`,
    `4) Quiet dream: ${safeAnswers[3]}`,
    latest,
    languageHint,
    "Output one cohesive paragraph only."
  ].join("\n");
}

function extractGeminiText(payload: Record<string, unknown>): string | null {
  const candidates = payload?.candidates as Array<Record<string, unknown>> | undefined;
  if (!Array.isArray(candidates) || !candidates.length) return null;

  const first = candidates[0];
  const content = first?.content as Record<string, unknown> | undefined;
  const parts = content?.parts as Array<Record<string, unknown>> | undefined;
  if (!Array.isArray(parts) || !parts.length) return null;

  const text = parts
    .map((part) => String(part?.text ?? ""))
    .join("\n")
    .trim();

  return text || null;
}

async function callGeminiWithFallback(
  apiKey: string,
  systemPrompt: string,
  userPrompt: string
): Promise<{ text: string; modelUsed: string }> {
  const models = ["gemini-2.0-flash", "gemini-2.0-flash-lite"];

  for (let i = 0; i < models.length; i += 1) {
    const model = models[i];
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: [{ text: userPrompt }] }],
        generationConfig: {
          temperature: 0.75,
          topP: 0.9,
          maxOutputTokens: 180
        }
      })
    });

    if (response.status === 429 && model === "gemini-2.0-flash") {
      continue;
    }

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini request failed (${model}) with status ${response.status}: ${errorText}`);
    }

    const payload = (await response.json()) as Record<string, unknown>;
    const text = extractGeminiText(payload);
    if (!text) {
      throw new Error(`Gemini response (${model}) contained no text`);
    }

    return { text, modelUsed: model };
  }

  throw new Error("Gemini rate-limited on primary model and fallback model unavailable");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { ok: false, error: "Method not allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

  if (!supabaseUrl || !serviceRoleKey || !geminiApiKey) {
    return json(500, {
      ok: false,
      error: "Missing environment variables",
      required: ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "GEMINI_API_KEY"]
    });
  }

  let body: GenerateIdentityRequest;
  try {
    body = (await req.json()) as GenerateIdentityRequest;
  } catch {
    return json(400, { ok: false, error: "Invalid JSON body" });
  }

  const userId = body?.userId?.trim();
  const answers = Array.isArray(body?.answers)
    ? body.answers.map((a) => String(a || "").trim())
    : [];
  const requestedLanguage = String(body?.language || "").trim().toLowerCase();
  const supportedLanguages = ["en", "de", "es", "fr", "pt", "it", "nl"];

  if (!userId) {
    return json(400, { ok: false, error: "userId is required" });
  }

  if (answers.length !== 4 || answers.some((a) => !a)) {
    return json(400, { ok: false, error: "answers must be a string[4] with non-empty values" });
  }

  if (requestedLanguage && !supportedLanguages.includes(requestedLanguage)) {
    return json(400, {
      ok: false,
      error: "language must be one of en,de,es,fr,pt,it,nl"
    });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  const { data: userRaw, error: userError } = await supabase
    .from("users")
    .select("id, display_name, name, language")
    .eq("id", userId)
    .maybeSingle();

  if (userError) {
    return json(500, { ok: false, error: `Failed to load user: ${userError.message}` });
  }

  const user = (userRaw as UserRow | null);

  if (!user) {
    return json(404, { ok: false, error: "User not found" });
  }

  const { data: checkins, error: checkinError } = await supabase
    .from("checkins")
    .select("body, mind, soul, energy, note, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(3);

  if (checkinError) {
    return json(500, { ok: false, error: `Failed to load check-ins: ${checkinError.message}` });
  }

  const language = (requestedLanguage || user.language || "en").toLowerCase();
  const displayName = user.display_name || user.name || "friend";

  const systemPrompt = buildMaiSystemPrompt(language);
  const userPrompt = buildIdentityPrompt(displayName, answers, (checkins || []) as CheckinRow[], language);

  let generatedText = "";
  let modelUsed = "fallback";
  let usedFallback = false;

  try {
    const result = await callGeminiWithFallback(geminiApiKey, systemPrompt, userPrompt);
    generatedText = sanitizeIdentityText(result.text);
    modelUsed = result.modelUsed;
  } catch (err) {
    console.error("generate-identity Gemini failure", err);
    usedFallback = true;
    generatedText = fallbackIdentity(answers, language);
  }

  if (!generatedText) {
    usedFallback = true;
    generatedText = fallbackIdentity(answers, language);
  }

  const sentences = splitSentences(generatedText);
  const oneLiner = sentences[0] || generatedText;

  const { data: prevIdentityRaw, error: prevError } = await supabase
    .from("identities")
    .select("id, version")
    .eq("user_id", userId)
    .eq("is_active", true)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (prevError) {
    return json(500, { ok: false, error: `Failed to load current identity: ${prevError.message}` });
  }

  const prevIdentity = prevIdentityRaw as { id: string; version: number | null } | null;
  const nextVersion = prevIdentity?.version ? Number(prevIdentity.version) + 1 : 1;

  const { error: archiveError } = await supabase
    .from("identities")
    .update({ is_active: false })
    .eq("user_id", userId)
    .eq("is_active", true);

  if (archiveError) {
    return json(500, { ok: false, error: `Failed to archive previous identity: ${archiveError.message}` });
  }

  const { data: inserted, error: insertError } = await supabase
    .from("identities")
    .insert({
      user_id: userId,
      full_text: generatedText,
      one_liner: oneLiner,
      sentences,
      language,
      is_active: true,
      version: nextVersion
    })
    .select("id, user_id, full_text, one_liner, sentences, language, version, created_at")
    .single();

  if (insertError) {
    return json(500, { ok: false, error: `Failed to save identity: ${insertError.message}` });
  }

  return json(200, {
    ok: true,
    identity: inserted,
    meta: {
      userId,
      language,
      modelUsed,
      fallbackUsed: usedFallback
    }
  });
});
