import Anthropic from "@anthropic-ai/sdk";
import type { Env } from "./index";
import { json } from "./http";
import { mockRecommendations } from "./mock";

export interface Favorite {
  title: string;
  authors: string[];
  rating: number;
}

export interface RecommendationRequest {
  favorites: Favorite[];
  /** Libros que no se deben recomendar: los de la biblioteca y los ya descartados. */
  exclude: string[];
  count: number;
}

export interface Recommendation {
  title: string;
  author: string;
  reason: string;
}

const MODEL = "claude-opus-5-5";

const SYSTEM_PROMPT = `Eres el librero de una librería independiente pequeña, con criterio propio y buena memoria lectora.
Un lector te comparte los libros que más ha disfrutado, con su puntuación de 0,5 a 5 estrellas.
Recomiéndale libros que de verdad existan y estén publicados, que encajen con lo que revelan sus favoritos (tono, temas, estilo, forma de narrar) y que le descubran algo: evita los títulos más obvios cuando haya una opción más personal igual de buena.
No recomiendes nada de la lista de excluidos ni otro libro de un autor cuando ya le das uno.
Escribe el título como se publicó en español si existe edición en español; si no, el original. En "author", solo el nombre del autor principal.
En "reason", una o dos frases en español, concretas y sin spoilers, que conecten la recomendación con uno o dos de sus favoritos por su nombre. Tono cálido y preciso, sin superlativos vacíos.`;

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    recommendations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          author: { type: "string" },
          reason: { type: "string" },
        },
        required: ["title", "author", "reason"],
        additionalProperties: false,
      },
    },
  },
  required: ["recommendations"],
  additionalProperties: false,
};

export async function handleRecommendations(request: Request, env: Env): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const input = parseRequest(body);
  if (!input) return json({ error: "invalid_request" }, 400);

  if (!env.ANTHROPIC_API_KEY) {
    if (env.MOCK_RECOMMENDATIONS === "true") {
      return json({ recommendations: mockRecommendations(input), source: "mock" });
    }
    return json({ error: "recommendations_not_configured" }, 503);
  }

  try {
    const recommendations = await recommendWithClaude(input, env.ANTHROPIC_API_KEY);
    return json({ recommendations, source: "claude" });
  } catch (error) {
    if (error instanceof RefusalError) return json({ error: "refused" }, 502);
    if (error instanceof InvalidOutputError) return json({ error: "invalid_model_output" }, 502);
    if (error instanceof Anthropic.RateLimitError) return json({ error: "rate_limited" }, 429);
    if (error instanceof Anthropic.AuthenticationError) {
      console.error("La clave de Anthropic no es válida");
      return json({ error: "recommendations_not_configured" }, 503);
    }
    if (error instanceof Anthropic.APIError) {
      console.error(`Anthropic API error ${error.status}`, error.message);
      return json({ error: "upstream" }, 502);
    }
    throw error;
  }
}

async function recommendWithClaude(input: RecommendationRequest, apiKey: string): Promise<Recommendation[]> {
  const client = new Anthropic({ apiKey });

  const favorites = input.favorites
    .map((book) => `- ${book.title} — ${book.authors.join(", ") || "autor desconocido"} (${book.rating} ★)`)
    .join("\n");
  const exclude = input.exclude.length > 0 ? input.exclude.map((title) => `- ${title}`).join("\n") : "(ninguno)";

  const response = await client.beta.messages.create({
    model: MODEL,
    max_tokens: 16000,
    // Si un clasificador de seguridad rechaza la petición, la API la repite
    // con el modelo alternativo que recomienda Anthropic.
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: {
      effort: "medium",
      format: { type: "json_schema", schema: RESPONSE_SCHEMA },
    },
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content: `Mis libros favoritos:\n${favorites}\n\nNo me recomiendes ninguno de estos:\n${exclude}\n\nRecomiéndame exactamente ${input.count} libros.`,
      },
    ],
  });

  if (response.stop_reason === "refusal") throw new RefusalError();

  const text = response.content.find((block) => block.type === "text");
  if (!text || text.type !== "text") throw new InvalidOutputError();

  let parsed: unknown;
  try {
    parsed = JSON.parse(text.text);
  } catch {
    throw new InvalidOutputError();
  }
  const list = (parsed as { recommendations?: unknown }).recommendations;
  if (!Array.isArray(list)) throw new InvalidOutputError();

  return list
    .filter(
      (item): item is Recommendation =>
        typeof item?.title === "string" && typeof item?.author === "string" && typeof item?.reason === "string",
    )
    .slice(0, input.count);
}

/** Valida el cuerpo y recorta tamaños para no mandar al modelo más de lo necesario. */
export function parseRequest(body: unknown): RecommendationRequest | null {
  if (typeof body !== "object" || body === null) return null;
  const { favorites, exclude, count } = body as Record<string, unknown>;

  if (!Array.isArray(favorites) || favorites.length === 0) return null;
  const cleanFavorites: Favorite[] = [];
  for (const item of favorites.slice(0, 30)) {
    const { title, authors, rating } = (item ?? {}) as Record<string, unknown>;
    if (typeof title !== "string" || title.trim() === "" || typeof rating !== "number") return null;
    cleanFavorites.push({
      title: title.slice(0, 200),
      authors: Array.isArray(authors) ? authors.filter((a): a is string => typeof a === "string").slice(0, 5) : [],
      rating: Math.min(Math.max(rating, 0.5), 5),
    });
  }

  const cleanExclude = Array.isArray(exclude)
    ? exclude.filter((e): e is string => typeof e === "string").slice(0, 300).map((e) => e.slice(0, 300))
    : [];

  const cleanCount = typeof count === "number" && Number.isInteger(count) ? Math.min(Math.max(count, 1), 5) : 3;

  return { favorites: cleanFavorites, exclude: cleanExclude, count: cleanCount };
}

class RefusalError extends Error {}
class InvalidOutputError extends Error {}
