import {initializeApp} from "firebase-admin/app";
import {DocumentReference, getFirestore, Timestamp} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {createHash} from "crypto";

initializeApp();

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const db = getFirestore();

const SECTION_ORDER = [
  {id: "core", title: "Core self"},
  {id: "love", title: "Love & bonds"},
  {id: "work", title: "Work & decisions"},
  {id: "path", title: "Life path"},
  {id: "now", title: "Right now"},
] as const;

type SectionId = (typeof SECTION_ORDER)[number]["id"];

interface PersonalitySection {
  id: SectionId;
  title: string;
  body: string;
}

interface DailyForecastPayload {
  dateKey: string;
  headline: string;
  focus: string;
  summary: string;
  loveTip: string;
  workTip: string;
  doToday: string;
  avoidToday: string;
  love: number;
  energy: number;
  mood: number;
  luck: number;
}

interface PartnerPayload {
  name?: string;
  birthDate?: string;
  birthTime?: string | null;
  city?: string;
  sunSign?: string;
}

interface TarotCardPayload {
  id?: string;
  name?: string;
  position?: string;
  isReversed?: boolean;
  suit?: string;
}

interface GenerateReadingRequest {
  type?: string;
  force?: boolean;
  dateKey?: string;
  partner?: PartnerPayload;
  imageBase64?: string;
  mimeType?: string;
  spread?: string;
  question?: string;
  cards?: TarotCardPayload[];
}

const COMPAT_AREAS = ["Love", "Passion", "Trust", "Values", "Emotions", "Marriage"] as const;

interface UserContext {
  name: string;
  sunSign: string;
  lifePath: number;
  concern: string;
  relationship: string;
  gender: string;
  city: string;
  birthDateKey: string;
}

export const generateReading = onCall(
  {
    secrets: [openaiApiKey],
    region: "us-central1",
    timeoutSeconds: 90,
    memory: "1GiB",
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }

    const uid = request.auth.uid;
    const payload = (request.data ?? {}) as GenerateReadingRequest;
    const type = payload.type ?? "personality";
    const force = payload.force === true;

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("failed-precondition", "Complete the quiz first.");
    }

    const user = userSnap.data() ?? {};
    const ctx = readUserContext(user);

    if (type === "personality") {
      if (!isPremium(user)) {
        throw new HttpsError("permission-denied", "Active subscription required.");
      }
      return generatePersonalityReading({
        userRef,
        ctx,
        apiKey: openaiApiKey.value(),
        force,
      });
    }

    if (type === "daily") {
      const dateKey = normalizeDateKey(payload.dateKey);
      return generateDailyReading({
        userRef,
        ctx,
        apiKey: openaiApiKey.value(),
        force,
        dateKey,
      });
    }

    if (type === "compatibility") {
      return generateCompatibilityReading({
        userRef,
        ctx,
        apiKey: openaiApiKey.value(),
        force,
        partnerPayload: payload.partner,
        userDoc: user,
      });
    }

    if (type === "palm") {
      return generatePalmReading({
        userRef,
        ctx,
        apiKey: openaiApiKey.value(),
        imageBase64: payload.imageBase64,
        mimeType: payload.mimeType,
      });
    }

    if (type === "tarot") {
      return generateTarotReading({
        userRef,
        ctx,
        apiKey: openaiApiKey.value(),
        spread: payload.spread,
        question: payload.question,
        cards: payload.cards,
      });
    }

    throw new HttpsError("invalid-argument", `Unsupported reading type: ${type}`);
  },
);

async function generatePersonalityReading(args: {
  userRef: DocumentReference;
  ctx: UserContext;
  apiKey: string;
  force: boolean;
}) {
  const inputHash = hashInput({
    name: args.ctx.name,
    birthDate: args.ctx.birthDateKey,
    sunSign: args.ctx.sunSign,
    lifePath: args.ctx.lifePath,
    concern: args.ctx.concern,
    relationship: args.ctx.relationship,
    gender: args.ctx.gender,
    city: args.ctx.city,
  });

  const readingRef = args.userRef.collection("readings").doc("personality");
  if (!args.force) {
    const cached = await readingRef.get();
    if (cached.exists) {
      const cachedData = cached.data() ?? {};
      if (cachedData.inputHash === inputHash && Array.isArray(cachedData.sections)) {
        return {
          type: "personality",
          sections: cachedData.sections,
          inputHash,
          cached: true,
        };
      }
    }
  }

  const sections = await generatePersonalitySections(args.apiKey, args.ctx);
  const doc = {
    type: "personality",
    sections,
    inputHash,
    model: "gpt-4o-mini",
    generatedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  };
  await readingRef.set(doc, {merge: true});

  return {
    type: "personality",
    sections,
    inputHash,
    cached: false,
  };
}

async function generateDailyReading(args: {
  userRef: DocumentReference;
  ctx: UserContext;
  apiKey: string;
  force: boolean;
  dateKey: string;
}) {
  const inputHash = hashInput({
    type: "daily",
    dateKey: args.dateKey,
    name: args.ctx.name,
    birthDate: args.ctx.birthDateKey,
    sunSign: args.ctx.sunSign,
    lifePath: args.ctx.lifePath,
    concern: args.ctx.concern,
    relationship: args.ctx.relationship,
  });

  const readingRef = args.userRef.collection("readings").doc(`daily_${args.dateKey}`);
  if (!args.force) {
    const cached = await readingRef.get();
    if (cached.exists) {
      const cachedData = cached.data() ?? {};
      if (cachedData.inputHash === inputHash && typeof cachedData.summary === "string") {
        return {
          type: "daily",
          cached: true,
          ...pickDailyFields(cachedData),
        };
      }
    }
  }

  const forecast = await generateDailyForecast(args.apiKey, args.ctx, args.dateKey);
  const doc = {
    type: "daily",
    ...forecast,
    inputHash,
    model: "gpt-4o-mini",
    generatedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  };
  await readingRef.set(doc, {merge: true});

  return {
    type: "daily",
    cached: false,
    ...forecast,
  };
}

function readUserContext(user: Record<string, unknown>): UserContext {
  const birthDate = timestampToDate(user.birthDate);
  if (!birthDate || typeof user.name !== "string" || !user.name.trim()) {
    throw new HttpsError("failed-precondition", "Birth profile incomplete.");
  }

  const sunSign =
    typeof user.sunSign === "string" && user.sunSign
      ? titleCase(user.sunSign)
      : sunSignForDate(birthDate);

  return {
    name: user.name.trim(),
    sunSign,
    lifePath: lifePathNumber(birthDate),
    concern: typeof user.concern === "string" ? user.concern : "selfDiscovery",
    relationship: typeof user.relationship === "string" ? user.relationship : "single",
    gender: typeof user.gender === "string" ? user.gender : "preferNotToSay",
    city: typeof user.city === "string" ? user.city : "",
    birthDateKey: birthDate.toISOString().slice(0, 10),
  };
}

function normalizeDateKey(value: unknown): string {
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return value;
  }
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, "0");
  const d = String(now.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function pickDailyFields(data: Record<string, unknown>): DailyForecastPayload {
  return {
    dateKey: String(data.dateKey ?? ""),
    headline: String(data.headline ?? ""),
    focus: String(data.focus ?? ""),
    summary: String(data.summary ?? ""),
    loveTip: String(data.loveTip ?? ""),
    workTip: String(data.workTip ?? ""),
    doToday: String(data.doToday ?? ""),
    avoidToday: String(data.avoidToday ?? ""),
    love: clampScore(data.love),
    energy: clampScore(data.energy),
    mood: clampScore(data.mood),
    luck: clampScore(data.luck),
  };
}

function clampScore(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return 50;
  return Math.max(1, Math.min(99, Math.round(n)));
}

function isPremium(user: Record<string, unknown>): boolean {
  if (user.subscriptionActive !== true) return false;
  const expires = timestampToDate(user.subscriptionExpiresAt);
  if (expires && expires.getTime() < Date.now()) return false;
  return true;
}

function timestampToDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === "object" && value !== null && "toDate" in value) {
    const maybe = value as {toDate?: () => Date};
    if (typeof maybe.toDate === "function") return maybe.toDate();
  }
  if (typeof value === "string" || typeof value === "number") {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  return null;
}

function hashInput(parts: Record<string, string | number>): string {
  return createHash("sha256").update(JSON.stringify(parts)).digest("hex").slice(0, 24);
}

async function callOpenAIJson(apiKey: string, system: string, user: string): Promise<Record<string, unknown>> {
  return callOpenAIMessages(apiKey, [
    {role: "system", content: system},
    {role: "user", content: user},
  ]);
}

async function callOpenAIMessages(
  apiKey: string,
  messages: Array<Record<string, unknown>>,
  temperature = 0.85,
): Promise<Record<string, unknown>> {
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature,
      response_format: {type: "json_object"},
      messages,
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    console.error("OpenAI error", response.status, detail);
    throw new HttpsError("internal", "Reading generation failed.");
  }

  const json = (await response.json()) as {
    choices?: Array<{message?: {content?: string}}>;
  };
  const content = json.choices?.[0]?.message?.content;
  if (!content) {
    throw new HttpsError("internal", "Empty model response.");
  }

  try {
    return JSON.parse(content) as Record<string, unknown>;
  } catch {
    throw new HttpsError("internal", "Invalid model JSON.");
  }
}

async function generateTarotReading(args: {
  userRef: DocumentReference;
  ctx: UserContext;
  apiKey: string;
  spread?: string;
  question?: string;
  cards?: TarotCardPayload[];
}) {
  const spread = args.spread === "single" ? "single" : "threeCard";
  const question = String(args.question ?? "").trim();
  if (!question) {
    throw new HttpsError("invalid-argument", "A question is required before reading tarot cards.");
  }

  const cards = (args.cards ?? [])
    .map((card) => ({
      id: String(card.id ?? "").trim(),
      name: String(card.name ?? "").trim(),
      position: String(card.position ?? "").trim(),
      isReversed: card.isReversed === true,
      suit: String(card.suit ?? "").trim(),
    }))
    .filter((card) => card.id && card.name && card.position);

  const expected = spread === "single" ? 1 : 3;
  if (cards.length !== expected) {
    throw new HttpsError("invalid-argument", `Tarot spread expects ${expected} cards.`);
  }

  const system = [
    "You write Glyfica tarot readings for an astrology app.",
    "Tone: warm, specific, modern, calm. No fatalism, no medical/financial/legal claims, no emojis.",
    "The reading MUST answer the user's question. Every card meaning should relate back to that question.",
    "Honor upright vs reversed meanings. Keep each card meaning to 2-3 sentences.",
    "Return ONLY valid JSON with exactly these keys:",
    '{"headline":"...","overview":"...","advice":"...","cards":[{"id":"...","name":"...","position":"...","isReversed":false,"meaning":"..."}]}',
    "headline: max 8 words. overview: 2 short paragraphs answering the question. advice: one practical sentence.",
    "cards array must keep the same order, ids, names, positions, and isReversed flags provided by the user.",
  ].join(" ");

  const cardLines = cards.map((card, index) =>
    `${index + 1}. [${card.position}] ${card.name}${card.isReversed ? " (Reversed)" : ""} — id=${card.id}, suit=${card.suit || "unknown"}`,
  ).join("\n");

  const user = [
    `Question: ${question}`,
    `Spread: ${spread === "single" ? "One card" : "Past / Present / Future"}`,
    `Name: ${args.ctx.name}`,
    `Sun sign: ${args.ctx.sunSign}`,
    `Life path: ${args.ctx.lifePath}`,
    `Focus: ${labelConcern(args.ctx.concern)}`,
    `Relationship: ${labelRelationship(args.ctx.relationship)}`,
    "",
    "Drawn cards:",
    cardLines,
    "",
    "Write a personalized reading that answers this exact question using this exact draw.",
  ].join("\n");

  const parsed = await callOpenAIJson(args.apiKey, system, user);
  const cardsRaw = Array.isArray(parsed.cards) ? parsed.cards : [];
  const byId = new Map<string, string>();
  for (const row of cardsRaw) {
    if (!row || typeof row !== "object") continue;
    const item = row as {id?: string; meaning?: string};
    if (typeof item.id === "string" && typeof item.meaning === "string" && item.meaning.trim()) {
      byId.set(item.id, item.meaning.trim());
    }
  }

  const meanings = cards.map((card) => {
    const meaning = byId.get(card.id);
    if (!meaning) {
      throw new HttpsError("internal", `Missing meaning for card ${card.id}`);
    }
    return {
      id: card.id,
      name: card.name,
      position: card.position,
      isReversed: card.isReversed,
      meaning,
    };
  });

  const reading = {
    id: `tarot_${Date.now()}`,
    spread,
    question,
    headline: String(parsed.headline ?? "").trim(),
    overview: String(parsed.overview ?? "").trim(),
    advice: String(parsed.advice ?? "").trim(),
    cards: meanings,
  };

  if (!reading.headline || !reading.overview) {
    throw new HttpsError("internal", "Incomplete tarot reading.");
  }

  await args.userRef.collection("readings").doc("tarot_latest").set({
    type: "tarot",
    ...reading,
    model: "gpt-4o-mini",
    generatedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  }, {merge: true});

  return {
    type: "tarot",
    cached: false,
    ...reading,
  };
}

async function generatePalmReading(args: {
  userRef: DocumentReference;
  ctx: UserContext;
  apiKey: string;
  imageBase64?: string;
  mimeType?: string;
}) {
  const raw = (args.imageBase64 ?? "").replace(/\s/g, "");
  if (!raw || raw.length < 1000) {
    throw new HttpsError("invalid-argument", "Palm photo required.");
  }
  // ~4MB base64 ceiling keeps the callable request practical.
  if (raw.length > 5_500_000) {
    throw new HttpsError("invalid-argument", "Photo is too large. Try a smaller image.");
  }

  const mime = args.mimeType === "image/png" ? "image/png" : "image/jpeg";
  const system = [
    "You are a palmistry reader for the Glyfica app.",
    "Look at the attached hand photo and write an entertainment palm reading.",
    "If the image is not a clear open palm, still be gentle and say what you can see, but prefer useful poetic guidance over refusal.",
    "Tone: warm, specific, calm, modern. No medical/financial/legal claims. No emojis.",
    "Return ONLY valid JSON with exactly these keys:",
    '{"headline":"...","overview":"...","lifeLine":"...","heartLine":"...","headLine":"...","fateLine":"...","nearFuture":"...","advice":"...","vitality":72,"emotion":68,"mind":75,"destiny":61,"outlook":70}',
    "headline: max 8 words. overview: 2 short paragraphs. each text field: 1-2 sentences.",
    "Scores are integers 40-96. vitality~life line, emotion~heart, mind~head, destiny~fate, outlook~near future.",
  ].join(" ");

  const userText = [
    `Name: ${args.ctx.name}`,
    `Sun sign: ${args.ctx.sunSign}`,
    `Life path: ${args.ctx.lifePath}`,
    `Focus: ${labelConcern(args.ctx.concern)}`,
    `Relationship: ${labelRelationship(args.ctx.relationship)}`,
    "",
    "Read this palm photo. Weave their chart lightly into the tone, but ground the reading in the hand lines you can see.",
  ].join("\n");

  const parsed = await callOpenAIMessages(args.apiKey, [
    {role: "system", content: system},
    {
      role: "user",
      content: [
        {type: "text", text: userText},
        {
          type: "image_url",
          image_url: {
            url: `data:${mime};base64,${raw}`,
            detail: "low",
          },
        },
      ],
    },
  ], 0.8);

  const reading = {
    id: `palm_${Date.now()}`,
    headline: String(parsed.headline ?? "").trim(),
    overview: String(parsed.overview ?? "").trim(),
    lifeLine: String(parsed.lifeLine ?? "").trim(),
    heartLine: String(parsed.heartLine ?? "").trim(),
    headLine: String(parsed.headLine ?? "").trim(),
    fateLine: String(parsed.fateLine ?? "").trim(),
    nearFuture: String(parsed.nearFuture ?? "").trim(),
    advice: String(parsed.advice ?? "").trim(),
    vitality: clampScore(parsed.vitality),
    emotion: clampScore(parsed.emotion),
    mind: clampScore(parsed.mind),
    destiny: clampScore(parsed.destiny),
    outlook: clampScore(parsed.outlook),
  };

  if (!reading.headline || !reading.overview) {
    throw new HttpsError("internal", "Incomplete palm reading.");
  }

  const doc = {
    type: "palm",
    ...reading,
    model: "gpt-4o-mini",
    generatedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  };
  await args.userRef.collection("readings").doc("palm_latest").set(doc, {merge: true});

  return {
    type: "palm",
    cached: false,
    ...reading,
  };
}

async function generatePersonalitySections(
  apiKey: string,
  ctx: UserContext,
): Promise<PersonalitySection[]> {
  const system = [
    "You write Glyfica personality readings for an astrology + numerology app.",
    "Tone: intimate, specific, modern, calm. No fatalism, no medical/financial/legal claims.",
    "No emojis. No bullet symbols except in Right now (numbered 1-3).",
    "Each section body: 2-3 short paragraphs, or for Right now exactly 3 soft numbered tips.",
    "Return ONLY valid JSON with this shape:",
    '{"sections":[{"id":"core","body":"..."},{"id":"love","body":"..."},{"id":"work","body":"..."},{"id":"path","body":"..."},{"id":"now","body":"..."}]}',
    "ids must be exactly: core, love, work, path, now.",
  ].join(" ");

  const user = [
    `Name: ${ctx.name}`,
    `Sun sign: ${ctx.sunSign}`,
    `Life path number: ${ctx.lifePath}`,
    `Current focus from quiz: ${labelConcern(ctx.concern)}`,
    `Relationship status: ${labelRelationship(ctx.relationship)}`,
    `Gender: ${labelGender(ctx.gender)}`,
    ctx.city ? `City: ${ctx.city}` : "City: unknown",
    "",
    "Write personalized sections:",
    "core = how they show up, strengths, shadow",
    "love = relationship tone matching their status",
    "work = how they decide, where they stall",
    "path = life-path meaning woven with their sun sign",
    "now = 3 soft tips tied to their current focus",
  ].join("\n");

  const parsed = await callOpenAIJson(apiKey, system, user);
  const sectionsRaw = Array.isArray(parsed.sections) ? parsed.sections : [];
  const byId = new Map<string, string>();
  for (const section of sectionsRaw) {
    if (!section || typeof section !== "object") continue;
    const row = section as {id?: string; body?: string};
    if (row.id && typeof row.body === "string" && row.body.trim()) {
      byId.set(row.id, row.body.trim());
    }
  }

  const sections: PersonalitySection[] = [];
  for (const meta of SECTION_ORDER) {
    const body = byId.get(meta.id);
    if (!body) {
      throw new HttpsError("internal", `Missing section: ${meta.id}`);
    }
    sections.push({id: meta.id, title: meta.title, body});
  }
  return sections;
}

async function generateCompatibilityReading(args: {
  userRef: DocumentReference;
  ctx: UserContext;
  apiKey: string;
  force: boolean;
  partnerPayload?: PartnerPayload;
  userDoc: Record<string, unknown>;
}) {
  const partner = resolvePartner(args.partnerPayload, args.userDoc);
  const inputHash = hashInput({
    type: "compatibility",
    userSign: args.ctx.sunSign,
    userBirth: args.ctx.birthDateKey,
    partnerName: partner.name,
    partnerBirth: partner.birthDateKey,
    partnerSign: partner.sunSign,
    relationship: args.ctx.relationship,
  });

  const docId = `compatibility_${partner.birthDateKey}_${partner.sunSign}_${slug(partner.name)}`;
  const readingRef = args.userRef.collection("readings").doc(docId);

  if (!args.force) {
    const cached = await readingRef.get();
    if (cached.exists) {
      const cachedData = cached.data() ?? {};
      if (cachedData.inputHash === inputHash && typeof cachedData.summary === "string") {
        return {
          type: "compatibility",
          cached: true,
          ...pickCompatibilityFields(cachedData, partner),
        };
      }
    }
  }

  const reading = await generateCompatibilityText(args.apiKey, args.ctx, partner);

  await args.userRef.set(
    {
      partner: {
        name: partner.name,
        birthDate: Timestamp.fromDate(partner.birthDate),
        birthTime: partner.birthTime ? Timestamp.fromDate(partner.birthTime) : null,
        city: partner.city,
        sunSign: partner.sunSign.toLowerCase(),
      },
      updatedAt: Timestamp.now(),
    },
    {merge: true},
  );

  const doc = {
    type: "compatibility",
    ...reading,
    inputHash,
    model: "gpt-4o-mini",
    generatedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  };
  await readingRef.set(doc, {merge: true});

  return {
    type: "compatibility",
    cached: false,
    ...reading,
  };
}

function resolvePartner(
  payload: PartnerPayload | undefined,
  userDoc: Record<string, unknown>,
): {
  name: string;
  birthDate: Date;
  birthDateKey: string;
  birthTime: Date | null;
  city: string;
  sunSign: string;
} {
  const fromDoc = (userDoc.partner && typeof userDoc.partner === "object")
    ? userDoc.partner as Record<string, unknown>
    : null;

  const name = String(payload?.name ?? fromDoc?.name ?? "").trim();
  const birthDateKey = normalizeDateKey(payload?.birthDate ?? dateKeyFromUnknown(fromDoc?.birthDate));
  const birthDate = parseDateKey(birthDateKey);
  if (!name || !birthDate) {
    throw new HttpsError("failed-precondition", "Partner details required.");
  }

  const sunSign = titleCase(
    String(payload?.sunSign ?? fromDoc?.sunSign ?? sunSignForDate(birthDate)),
  );
  const city = String(payload?.city ?? fromDoc?.city ?? "");

  let birthTime: Date | null = null;
  if (typeof payload?.birthTime === "string" && /^\d{2}:\d{2}$/.test(payload.birthTime)) {
    const [hh, mm] = payload.birthTime.split(":").map(Number);
    birthTime = new Date(Date.UTC(
      birthDate.getUTCFullYear(),
      birthDate.getUTCMonth(),
      birthDate.getUTCDate(),
      hh,
      mm,
    ));
  } else {
    birthTime = timestampToDate(fromDoc?.birthTime);
  }

  return {name, birthDate, birthDateKey, birthTime, city, sunSign};
}

function dateKeyFromUnknown(value: unknown): string | undefined {
  const date = timestampToDate(value);
  if (!date) return typeof value === "string" ? value : undefined;
  return date.toISOString().slice(0, 10);
}

function parseDateKey(dateKey: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) return null;
  const [y, m, d] = dateKey.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

function slug(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "")
    .slice(0, 32) || "partner";
}

function pickCompatibilityFields(
  data: Record<string, unknown>,
  partner: {name: string; sunSign: string},
) {
  return {
    partnerName: String(data.partnerName ?? partner.name),
    partnerSign: String(data.partnerSign ?? partner.sunSign),
    overall: clampScore(data.overall),
    headline: String(data.headline ?? ""),
    summary: String(data.summary ?? ""),
    tip: String(data.tip ?? ""),
    areas: Array.isArray(data.areas) ? data.areas : [],
  };
}

async function generateCompatibilityText(
  apiKey: string,
  ctx: UserContext,
  partner: {name: string; sunSign: string; birthDateKey: string; city: string},
) {
  const system = [
    "You write Glyfica compatibility readings for an astrology app.",
    "Tone: warm, specific, modern, calm. No fatalism, no medical/financial/legal claims, no emojis.",
    "Return ONLY valid JSON with exactly these keys:",
    '{"overall":78,"headline":"...","summary":"...","tip":"...","areas":[{"title":"Love","score":80},{"title":"Passion","score":74},{"title":"Trust","score":70},{"title":"Values","score":76},{"title":"Emotions","score":72},{"title":"Marriage","score":69}]}',
    "headline: max 8 words. summary: 2 short paragraphs. tip: one practical sentence.",
    "areas must include exactly these titles: Love, Passion, Trust, Values, Emotions, Marriage.",
    "Scores are integers from 40 to 96. overall should reflect the same tone as the areas.",
  ].join(" ");

  const user = [
    `You: ${ctx.name}, ${ctx.sunSign}, life path ${ctx.lifePath}`,
    `Relationship status: ${labelRelationship(ctx.relationship)}`,
    `Your focus: ${labelConcern(ctx.concern)}`,
    `Them: ${partner.name}, ${partner.sunSign}, born ${partner.birthDateKey}`,
    partner.city ? `Their city: ${partner.city}` : "Their city: unknown",
    "",
    "Write a personalized chemistry reading for these two people.",
  ].join("\n");

  const parsed = await callOpenAIJson(apiKey, system, user);
  const areasRaw = Array.isArray(parsed.areas) ? parsed.areas : [];
  const byTitle = new Map<string, number>();
  for (const row of areasRaw) {
    if (!row || typeof row !== "object") continue;
    const item = row as {title?: string; score?: unknown};
    if (typeof item.title === "string") {
      byTitle.set(item.title, clampScore(item.score));
    }
  }

  const areas = COMPAT_AREAS.map((title) => ({
    title,
    score: byTitle.get(title) ?? 60,
  }));

  const headline = String(parsed.headline ?? "").trim();
  const summary = String(parsed.summary ?? "").trim();
  const tip = String(parsed.tip ?? "").trim();
  if (!headline || !summary) {
    throw new HttpsError("internal", "Incomplete compatibility reading.");
  }

  return {
    partnerName: partner.name,
    partnerSign: partner.sunSign,
    overall: clampScore(parsed.overall),
    headline,
    summary,
    tip,
    areas,
  };
}

async function generateDailyForecast(
  apiKey: string,
  ctx: UserContext,
  dateKey: string,
): Promise<DailyForecastPayload> {
  const system = [
    "You write Glyfica daily forecasts for an astrology + numerology app.",
    "Tone: warm, specific, practical, calm. Speak to one person.",
    "No fatalism, no medical/financial/legal claims, no emojis.",
    "Keep lines short and human. Scores are integers from 40 to 95.",
    "Return ONLY valid JSON with exactly these keys:",
    '{"headline":"...","focus":"...","summary":"...","loveTip":"...","workTip":"...","doToday":"...","avoidToday":"...","love":72,"energy":68,"mood":75,"luck":61}',
    "headline: max 8 words. focus: one short sentence. summary: 2 short paragraphs.",
    "loveTip/workTip/doToday/avoidToday: one sentence each.",
  ].join(" ");

  const user = [
    `Today's date: ${dateKey}`,
    `Name: ${ctx.name}`,
    `Sun sign: ${ctx.sunSign}`,
    `Life path number: ${ctx.lifePath}`,
    `Current focus from quiz: ${labelConcern(ctx.concern)}`,
    `Relationship status: ${labelRelationship(ctx.relationship)}`,
    `Gender: ${labelGender(ctx.gender)}`,
    ctx.city ? `City: ${ctx.city}` : "City: unknown",
    "",
    "Write a personalized forecast for THIS calendar day only.",
    "Lean into their quiz focus and relationship status.",
  ].join("\n");

  const parsed = await callOpenAIJson(apiKey, system, user);
  const forecast: DailyForecastPayload = {
    dateKey,
    headline: String(parsed.headline ?? "").trim(),
    focus: String(parsed.focus ?? "").trim(),
    summary: String(parsed.summary ?? "").trim(),
    loveTip: String(parsed.loveTip ?? "").trim(),
    workTip: String(parsed.workTip ?? "").trim(),
    doToday: String(parsed.doToday ?? "").trim(),
    avoidToday: String(parsed.avoidToday ?? "").trim(),
    love: clampScore(parsed.love),
    energy: clampScore(parsed.energy),
    mood: clampScore(parsed.mood),
    luck: clampScore(parsed.luck),
  };

  if (!forecast.headline || !forecast.focus || !forecast.summary) {
    throw new HttpsError("internal", "Incomplete daily forecast.");
  }

  return forecast;
}

function lifePathNumber(date: Date): number {
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + 1;
  const day = date.getUTCDate();
  const digits = `${year}${month}${day}`.split("").map(Number);
  return reduceLifePath(digits.reduce((a, b) => a + b, 0));
}

function reduceLifePath(value: number): number {
  if (value === 11 || value === 22 || value === 33) return value;
  if (value < 10) return value;
  const next = String(value)
    .split("")
    .map(Number)
    .reduce((a, b) => a + b, 0);
  return reduceLifePath(next);
}

function sunSignForDate(date: Date): string {
  const month = date.getUTCMonth() + 1;
  const day = date.getUTCDate();
  const md = month * 100 + day;
  if (md >= 321 && md <= 419) return "Aries";
  if (md >= 420 && md <= 520) return "Taurus";
  if (md >= 521 && md <= 620) return "Gemini";
  if (md >= 621 && md <= 722) return "Cancer";
  if (md >= 723 && md <= 822) return "Leo";
  if (md >= 823 && md <= 922) return "Virgo";
  if (md >= 923 && md <= 1022) return "Libra";
  if (md >= 1023 && md <= 1121) return "Scorpio";
  if (md >= 1122 && md <= 1221) return "Sagittarius";
  if (md >= 1222 || md <= 119) return "Capricorn";
  if (md >= 120 && md <= 218) return "Aquarius";
  return "Pisces";
}

function titleCase(value: string): string {
  if (!value) return value;
  return value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
}

function labelConcern(value: string): string {
  switch (value) {
  case "love":
    return "Love";
  case "career":
    return "Career";
  case "decision":
    return "A decision";
  case "selfDiscovery":
    return "Self-discovery";
  default:
    return value;
  }
}

function labelRelationship(value: string): string {
  switch (value) {
  case "single":
    return "Single";
  case "talking":
    return "Talking to someone";
  case "inRelationship":
    return "In a relationship";
  case "complicated":
    return "It's complicated";
  case "married":
    return "Married";
  default:
    return value;
  }
}

function labelGender(value: string): string {
  switch (value) {
  case "female":
    return "Female";
  case "male":
    return "Male";
  case "preferNotToSay":
    return "Prefer not to say";
  default:
    return value;
  }
}
