# MaiTribe — Codex Round 3: Alle Fixes aus dem Live-Test
## February 20, 2026

---

## KONTEXT

Wir haben die App live getestet. Auth, Supabase, Onboarding, Home-Screen funktionieren grundsätzlich. Die folgenden Fixes sind priorisiert nach Impact.

**Reihenfolge: Erst 1-3 (brechen die App), dann 4-6 (machen sie besser).**

---

## FIX 1: UTF-8 UMLAUTE (KRITISCH)

### Problem:
Alle deutschen Umlaute (ä, ö, ü, ß) werden als einfache Buchstaben angezeigt:
- "Identitat" statt "Identität"
- "Korper" statt "Körper"  
- "anfuhlt" statt "anfühlt"
- "Prasenz" statt "Präsenz"

### Ursache:
Die i18n-Strings im JavaScript enthalten keine echten UTF-8-Umlaute, sondern ASCII-Versionen.

### Lösung:
Ersetze ALLE deutschen i18n-Strings mit korrekt kodierten Umlauten. Hier ist das komplette deutsche i18n-Objekt — **ersetze das bestehende `de`-Objekt vollständig**:

```javascript
de: {
  // Onboarding Step 1
  onboard_welcome_title: "Willkommen.",
  onboard_welcome_text: "Ich bin Mai \u2014 deine Begleiterin f\u00FCr K\u00F6rper, Geist und Seele.\n\nIch bin kein Chatbot. Kein Coach. Keine App, die dir sagt, was du tun sollst.\n\nIch bin eine stille Pr\u00E4senz. Ich h\u00F6re zu. Ich erinnere mich. Ich gehe neben dir.\n\nLass uns damit anfangen, uns kennenzulernen.",
  onboard_begin: "Los geht\u2019s",

  // Onboarding Step 2
  onboard_name_label: "Wie soll ich dich nennen?",
  onboard_language_label: "Sprache",
  onboard_timezone_label: "Zeitzone",
  onboard_continue: "Weiter",

  // Onboarding Step 3
  onboard_checkin_title: "Wie geht es dir gerade?",
  onboard_checkin_sub: "Nicht wie du denkst, dass es dir gehen sollte. Wie es dir wirklich geht.",
  onboard_checkin_note_label: "Was bewegt dich gerade? (optional)",
  onboard_checkin_note_placeholder: "Teile, was sich gerade wahr anf\u00FChlt...",
  onboard_checkin_btn: "Wie f\u00FChlt sich das heute an?",

  // Onboarding Step 4
  onboard_identity_title: "Deine Identit\u00E4t",
  onboard_identity_sub: "Ich stelle dir vier kurze Fragen. Es gibt keine falschen Antworten.",
  onboard_identity_placeholder: "Schreib, was sich wahr anf\u00FChlt...",
  onboard_identity_save_answer: "Antwort speichern",
  onboard_identity_generate: "Identit\u00E4t erstellen",
  onboard_identity_generated_label: "Deine erstellte Identit\u00E4t (du kannst sie bearbeiten)",

  // Onboarding Step 5
  onboard_reminders_title: "Sanfte Erinnerungen",
  onboard_wake_label: "Wann wachst du auf?",
  onboard_morning_label: "Morgen-Identit\u00E4ts-Erinnerung",
  onboard_morning_help: "Eine ruhige Erinnerung jeden Morgen.",
  onboard_mindful_label: "Achtsame Erinnerungen",
  onboard_mindful_help: "Kleine erdende Impulse durch den Tag.",
  onboard_mindful_count_label: "Achtsame Erinnerungen pro Tag",
  onboard_notify: "Benachrichtigungen aktivieren",
  onboard_ready: "Ich bin bereit",

  // Identity questions
  identity_q1: "Stell dir vor, du wachst morgen auf und lebst dein absolutes Traumleben. Wo bist du? Was tust du? Wie f\u00FChlt sich dein K\u00F6rper an? Beschreib es so konkret wie m\u00F6glich.",
  identity_q2: "Was ist dir im Leben am wichtigsten? Nicht was wichtig sein sollte \u2014 was es wirklich ist, tief in dir drin.",
  identity_q3: "Welches Gef\u00FChl w\u00FCnschst du dir mehr in deinem Alltag? Nicht was du tun willst \u2014 wie du dich f\u00FChlen willst.",
  identity_q4: "Gibt es einen Traum, den du in dir tr\u00E4gst, den du selten laut aussprichst? Einen, der sich fast zu gro\u00DF anf\u00FChlt?",
  identity_accept: "Das f\u00FChlt sich richtig an",

  // Home
  home_today: "Heute",
  home_identity_label: "\uD83C\uDF3F Deine Identit\u00E4t",
  home_checkin: "Check-in",
  home_checkin_sub: "K\u00F6rper \u00B7 Geist \u00B7 Seele",
  home_chat: "Mit Mai sprechen",
  home_chat_sub: "Stille Begleitung",
  home_recent: "Letzter Impuls",
  home_no_insight: "Noch keine Reflexionen.",

  // Greeting
  greeting_night: "Noch wach, {name}?",
  greeting_morning: "Guten Morgen, {name}",
  greeting_afternoon: "Guten Nachmittag, {name}",
  greeting_evening: "Guten Abend, {name}",
  greeting_late: "Gute Nacht, {name}",

  // Chat
  chat_placeholder: "Teile, was dich bewegt...",
  chat_back: "Zur\u00FCck",
  chat_refresh: "Neu laden",
  chat_mic: "Mikro",
  chat_send: "Senden",
  chat_mai_resting: "Mai ruht sich gerade kurz aus. Versuch es in einer Minute noch einmal. \uD83C\uDF3F",
  chat_no_key: "Bitte trage deinen Gemini API Key in den Einstellungen ein.",
  chat_fallback_opening: "Hey. Ich bin da. Was bewegt dich gerade am meisten?",

  // Check-in
  checkin_title: "Wie geht es dir \u2014 wirklich?",
  checkin_back: "Zur\u00FCck",
  checkin_note_label: "Was bewegt dich gerade? (optional)",
  checkin_note_placeholder: "Du kannst es kurz halten.",
  checkin_submit: "Check-in abschicken",
  checkin_saving: "Speichere...",
  checkin_saved: "Gespeichert.",

  // Identity screen
  identity_back: "Zur\u00FCck",
  identity_edit: "Bearbeiten",
  identity_cancel: "Abbrechen",
  identity_save: "Speichern",
  identity_empty: "Noch keine Identit\u00E4t erstellt.",
  identity_edit_label: "Identit\u00E4t bearbeiten",

  // Settings
  settings_title: "Einstellungen",
  settings_logout: "Abmelden",
  settings_profile: "Profil",
  settings_name_label: "Name",
  settings_language_label: "Sprache",
  settings_timezone_label: "Zeitzone",
  settings_reminders: "Erinnerungen",
  settings_morning_time: "Zeit der Morgen-Erinnerung",
  settings_morning_enabled: "Morgen-Erinnerung aktiv",
  settings_mindful_enabled: "Achtsame Erinnerungen aktiv",
  settings_mindful_count: "Achtsame Erinnerungen pro Tag",
  settings_event_enabled: "Event-Nachfragen aktiv",
  settings_keys: "Projekt-Schl\u00FCssel",
  settings_save: "Einstellungen speichern",
  settings_push: "Push-Benachrichtigungen aktivieren",
  settings_saved: "Gespeichert.",

  // Nav
  nav_home: "Home",
  nav_chat: "Chat",
  nav_profile: "Profil",

  // Slider labels
  slider_body: "K\u00F6rper",
  slider_mind: "Geist",
  slider_soul: "Seele",
  slider_energy: "Energie"
}
```

### WICHTIG — Unicode-Escape-Sequenzen:
Falls die Datei trotzdem keine Umlaute anzeigt, verwende die Unicode-Escape-Variante:
- ä = `\u00E4`
- ö = `\u00F6`  
- ü = `\u00FC`
- Ä = `\u00C4`
- Ö = `\u00D6`
- Ü = `\u00DC`
- ß = `\u00DF`
- — (em dash) = `\u2014`
- ' (curly apostrophe) = `\u2019`

Die Strings oben nutzen bereits Unicode-Escapes um das Problem zu vermeiden.

---

## FIX 2: VOLLSTÄNDIGE ÜBERSETZUNG ALLER UI-ELEMENTE (KRITISCH)

### Problem:
Viele UI-Elemente sind noch hardcoded auf Englisch:
- "Good evening, Freddy" → "Guten Abend, Freddy"
- "Check-in" / "Talk to Mai" / "Quiet support" (Home-Buttons)
- "Body" / "Mind" / "Soul" / "Energy" (Slider-Labels)
- "Recent insight" / "No reflections yet."
- "Back" / "Refresh" / "Mic" / "Send" (Chat-Screen)
- "Continue" (Onboarding Step 3)
- "Your generated identity (editable)" (Onboarding Step 4)
- "Mindful reminders per day" (Onboarding Step 5)
- Alle Settings-Labels

### Lösung:
Jedes hardcoded Text-Element im HTML muss dynamisch über die `t()` Funktion gesetzt werden. 

**Ansatz:** Erstelle eine Funktion `applyTranslations()` die nach jedem Screen-Wechsel und nach Sprachwahl aufgerufen wird:

```javascript
function applyTranslations() {
  // Home screen
  const homeGreeting = getEl("home-greeting");
  if (homeGreeting && appState.profile) {
    const name = appState.profile.display_name || appState.profile.name || "friend";
    const hour = new Date().getHours();
    if (hour < 5) homeGreeting.textContent = t("greeting_night").replace("{name}", name);
    else if (hour < 12) homeGreeting.textContent = t("greeting_morning").replace("{name}", name);
    else if (hour < 17) homeGreeting.textContent = t("greeting_afternoon").replace("{name}", name);
    else if (hour < 21) homeGreeting.textContent = t("greeting_evening").replace("{name}", name);
    else homeGreeting.textContent = t("greeting_late").replace("{name}", name);
  }

  // Home elements
  setText("home-identity-label", t("home_identity_label"));  // needs a span/element with this ID
  setText("home-recent-label", t("home_recent"));
  
  // Home buttons - need IDs on the text content
  const checkinBtn = getEl("btn-home-checkin");
  if (checkinBtn) checkinBtn.innerHTML = t("home_checkin") + "<small>" + t("home_checkin_sub") + "</small>";
  const chatBtn = getEl("btn-home-chat");
  if (chatBtn) chatBtn.innerHTML = t("home_chat") + "<small>" + t("home_chat_sub") + "</small>";

  // Chat screen
  setText("btn-chat-back", t("chat_back"));
  setText("btn-chat-refresh", t("chat_refresh"));
  setText("btn-chat-voice", t("chat_mic"));
  setText("btn-chat-send", t("chat_send"));
  getEl("chat-input").placeholder = t("chat_placeholder");

  // Check-in screen
  // Update slider labels
  document.querySelectorAll(".slider-wrap .slider-row span").forEach((span, i) => {
    const keys = ["slider_body", "slider_mind", "slider_soul", "slider_energy"];
    if (keys[i]) span.textContent = t(keys[i]);
  });

  // Nav
  const navButtons = getEl("bottom-nav").querySelectorAll("button");
  const navKeys = ["nav_home", "nav_chat", "nav_profile"];
  navButtons.forEach((btn, i) => {
    if (navKeys[i]) {
      // Preserve icon prefix if present
      const icon = btn.textContent.match(/^[^\w]*/)?.[0] || "";
      btn.innerHTML = icon + " " + t(navKeys[i]);
    }
  });
}

function setText(id, text) {
  const el = getEl(id);
  if (el) el.textContent = text;
}
```

Call `applyTranslations()` in:
- `loadHomeScreen()`
- `showScreen()` (after toggling active)
- After language change in settings
- After onboarding language selection

---

## FIX 3: GEMINI API ERROR HANDLING + RETRY (KRITISCH)

### Problem:
Wenn die Gemini API ein 429 (Rate Limit) zurückgibt:
- Chat bleibt komplett leer — kein Feedback an den User
- Identity-Generation zeigt generischen Fallback ohne Erklärung
- Kein Retry-Mechanismus

### Lösung:

**3a. Retry-Logik in callGemini():**
```javascript
async function callGemini(options, retryCount = 0) {
  const key = appState.config.geminiApiKey;
  if (!key) return { error: "no_key" };

  try {
    const response = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" + encodeURIComponent(key),
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: options.systemPrompt || "" }] },
          contents: options.contents || [],
          generationConfig: {
            temperature: options.temperature ?? 0.8,
            topP: options.topP ?? 0.9,
            maxOutputTokens: options.maxOutputTokens ?? 320
          }
        })
      }
    );

    // Rate limit — retry once after delay
    if (response.status === 429 && retryCount < 2) {
      const retryAfter = 15 + (retryCount * 15); // 15s, then 30s
      console.log("Gemini rate limited, retrying in " + retryAfter + "s...");
      await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
      return callGemini(options, retryCount + 1);
    }

    if (!response.ok) {
      const errorText = await response.text();
      console.error("Gemini error:", errorText);
      return { error: "api_error", status: response.status };
    }

    return await response.json();
  } catch (error) {
    console.error("Gemini request failed", error);
    return { error: "network_error" };
  }
}
```

**3b. Chat zeigt Fallback-Nachricht bei Fehler:**
```javascript
// In initChat(), after the opening message call:
if (!openingText || openingText.error) {
  const fallback = t("chat_fallback_opening");
  appendMessageBubble("assistant", "\uD83C\uDF3F " + fallback);
  // Don't save error messages to DB
  return;
}
```

**3c. Chat zeigt Fehler bei laufendem Gespräch:**
```javascript
// In sendMessage(), when response fails:
if (!response || response.error) {
  typingBubble.remove();
  if (response && response.error === "no_key") {
    appendMessageBubble("assistant", "\uD83C\uDF3F " + t("chat_no_key"));
  } else {
    appendMessageBubble("assistant", "\uD83C\uDF3F " + t("chat_mai_resting"));
  }
  return;
}
```

---

## FIX 4: IDENTITY-FRAGEN VERBESSERN (WICHTIG)

### Problem:
Die Fragen sind zu abstrakt und liefern deshalb zu generische Antworten. Besonders Q1 braucht mehr Kontext.

### Lösung:
Die neuen Fragen sind bereits im i18n-Objekt oben enthalten. Hier die englischen Versionen:

```javascript
// English identity questions:
identity_q1: "Imagine you wake up tomorrow living your absolute dream life. Where are you? What are you doing? How does your body feel? Describe it as concretely as you can.",
identity_q2: "What matters most to you in life? Not what should matter \u2014 what truly does, deep down.",
identity_q3: "What feeling do you want more of in your daily life? Not what you want to do \u2014 how you want to feel.",
identity_q4: "Is there a dream you carry inside that you rarely say out loud? One that feels almost too big?"
```

### Zusätzlich — Identity-Generation-Prompt verbessern:

```javascript
async function generateIdentityFromAnswers() {
  const answers = appState.onboarding.answers;
  const lang = getLanguageName(getEl("onboard-language").value);
  
  const prompt = `You are Mai. You just had a deep onboarding conversation.

Their answers about their life:
- Dream life (where, what, how it feels): ${answers[0]}
- What matters most: ${answers[1]}
- Feeling they want more of: ${answers[2]}
- Secret dream: ${answers[3]}

Write their personal Identity statement. Rules:
- 6-8 sentences in first person ("I am...", "I choose...", "I trust...")
- Make it feel TRUE, not aspirational-fake. Grounded, not fluffy.
- Include: their body, their mind, their relationships, their purpose, their dream.
- Use THEIR specific words and details — don't generalize.
- If they mentioned a place (e.g. California), include it specifically.
- If they mentioned a feeling (e.g. freedom, peace), anchor it in a concrete image.
- End with something grounding — quiet power, not hype.
- Do NOT use phrases like "I am worthy" or "I deserve" — too generic.
- Write like a poet, not a life coach.

Write in ${lang}.`;

  const response = await callGeminiRaw(prompt, 500);
  // ... rest of function
}
```

---

## FIX 5: STEP PROGRESS AUF DEUTSCH (WICHTIG)

### Problem:
"STEP 1 OF 5" ist immer Englisch.

### Lösung:
```javascript
function setOnboardingStep(step) {
  appState.onboarding.step = step;
  const lang = getEl("onboard-language")?.value || appState.profile?.language || "en";
  if (lang === "de") {
    getEl("onboard-progress").textContent = "Schritt " + step + " von 5";
  } else {
    getEl("onboard-progress").textContent = "Step " + step + " of 5";
  }
  // ... rest of function
}
```

---

## FIX 6: KLEINE UI-VERBESSERUNGEN (NICE TO HAVE)

### 6a. Auth-Screen auch übersetzen
"Your space. Your truth. Always private." → "Dein Raum. Deine Wahrheit. Immer privat."
"Continue with Email" → "Weiter mit E-Mail"
"Continue with Google" → "Weiter mit Google"

### 6b. Empty-State im Chat
Wenn der Chat leer ist und Mai nicht antwortet, zeige statt nichts:
```html
<div class="chat-empty-state">
  <p style="color: var(--muted); text-align: center; margin-top: 40%;">
    🌿<br>Mai lädt...<br>
    <small>Einen Moment noch.</small>
  </p>
</div>
```
Entferne dieses Element sobald die erste Nachricht erscheint.

### 6c. "Today" auf Home-Screen
Der Text "Today" über dem Greeting sollte auch übersetzt werden → "Heute"

### 6d. Slider-Labels im Check-in Screen
Auch der Check-in-Screen (nicht nur Onboarding) braucht übersetzte Labels:
- Body → Körper
- Mind → Geist  
- Soul → Seele
- Energy → Energie

### 6e. Fallback-Identity auf Deutsch verbessern
Die aktuelle Fallback-Identity ist zu generisch. Bessere Version:

```javascript
function fallbackIdentity(answers, languageCode) {
  if (languageCode === "de") {
    return "Ich lebe ein Leben, das sich echt anf\u00FChlt \u2014 " +
      "in meinem K\u00F6rper zuhause, in meinem Kopf klar, in meinem Herzen offen. " +
      "Ich richte meine Tage nach dem aus, was mir wirklich wichtig ist. " +
      "Ich w\u00E4hle Beziehungen, in denen Vertrauen und echte N\u00E4he wachsen k\u00F6nnen. " +
      "Ich nehme mir Raum f\u00FCr das, was mich lebendig macht. " +
      "Mein Traum darf sichtbar werden \u2014 Schritt f\u00FCr Schritt. " +
      "Ich gehe meinen Weg mit Ruhe, Mut und einem offenen Herzen.";
  }
  return "I live a life that feels real \u2014 " +
    "at home in my body, clear in my mind, open in my heart. " +
    "I align my days with what truly matters to me. " +
    "I choose relationships where trust and closeness can grow. " +
    "I make space for what makes me feel alive. " +
    "My dream is allowed to become visible \u2014 step by step. " +
    "I walk my path with calm, courage, and an open heart.";
}
```

---

## BUILD ORDER:

1. **Fix 1** — UTF-8 Umlaute (ersetze komplettes de-Objekt) 
2. **Fix 2** — applyTranslations() Funktion + Aufrufe  
3. **Fix 3** — Gemini Retry + Error-Fallbacks im Chat
4. **Fix 4** — Identity-Fragen + Generation-Prompt
5. **Fix 5** — Step-Progress auf Deutsch
6. **Fix 6** — Restliche UI-Strings

## VALIDIERUNG NACH DEM BUILD:

- [ ] Alle Umlaute korrekt angezeigt (ä, ö, ü, ß, Ä, Ö, Ü)
- [ ] Komplettes Onboarding auf Deutsch durchklickbar
- [ ] Home-Screen komplett auf Deutsch
- [ ] Chat zeigt Fallback-Nachricht wenn API nicht erreichbar
- [ ] Chat zeigt Loading-State wenn leer
- [ ] Check-in Slider-Labels auf Deutsch
- [ ] Nav-Bar auf Deutsch
- [ ] Settings-Screen auf Deutsch
- [ ] Identity-Fragen konkreter und persönlicher
- [ ] Fallback-Identity natürlicher

---

*Erst die Sprache heilen, dann die Seele sprechen lassen. 🌿*
