import { proxyGoogleBooks } from "./googleBooks";
import { handleRecommendations, recommendationProvider } from "./recommendations";
import { json } from "./http";

export interface Env {
  /** Workers AI (gratis dentro de la cuota diaria). */
  AI?: Ai;
  /** Modelo de Workers AI; se define en wrangler.toml para cambiarlo sin tocar código. */
  WORKERS_AI_MODEL?: string;
  /** Opcional: si está, las recomendaciones las hace Claude en vez de Workers AI. */
  ANTHROPIC_API_KEY?: string;
  GOOGLE_BOOKS_API_KEY?: string;
  /** Si está definido, la app debe enviarlo en la cabecera X-Booker-Token. */
  APP_TOKEN?: string;
  /** "true" para responder recomendaciones de ejemplo cuando no hay clave de Anthropic. */
  MOCK_RECOMMENDATIONS?: string;
}

export default {
  async fetch(request, env, ctx): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        googleBooks: Boolean(env.GOOGLE_BOOKS_API_KEY),
        recommendations: recommendationProvider(env),
      });
    }

    if (env.APP_TOKEN && request.headers.get("X-Booker-Token") !== env.APP_TOKEN) {
      return json({ error: "unauthorized" }, 401);
    }

    try {
      if (request.method === "GET" && url.pathname === "/books/v1/volumes") {
        return await proxyGoogleBooks(url, env, ctx);
      }
      if (request.method === "POST" && url.pathname === "/recommendations") {
        return await handleRecommendations(request, env);
      }
      return json({ error: "not_found" }, 404);
    } catch (error) {
      console.error("Unhandled error", error);
      return json({ error: "internal" }, 500);
    }
  },
} satisfies ExportedHandler<Env>;
