import type { Env } from "./index";
import { json } from "./http";

/** Parámetros que la app puede reenviar. El resto se descarta. */
const ALLOWED_PARAMS = ["q", "maxResults", "printType", "startIndex", "langRestrict", "orderBy"];

/**
 * Reenvía `GET /books/v1/volumes` a Google Books añadiendo la clave.
 * La app nunca ve la clave. Las respuestas correctas se guardan un día en la
 * caché de Cloudflare para ahorrar cuota (en *.workers.dev la caché no actúa,
 * pero no estorba).
 */
export async function proxyGoogleBooks(url: URL, env: Env, ctx: ExecutionContext): Promise<Response> {
  if (!env.GOOGLE_BOOKS_API_KEY) {
    return json({ error: "google_books_not_configured" }, 503);
  }

  const upstream = new URL("https://www.googleapis.com/books/v1/volumes");
  for (const name of ALLOWED_PARAMS) {
    const value = url.searchParams.get(name);
    if (value !== null) upstream.searchParams.set(name, value);
  }
  const query = upstream.searchParams.get("q");
  if (!query || query.length > 300) {
    return json({ error: "invalid_query" }, 400);
  }

  // La clave de caché no incluye la API key.
  const cacheKey = new Request(upstream.toString());
  const cache = caches.default;
  const cached = await cache.match(cacheKey);
  if (cached) return cached;

  upstream.searchParams.set("key", env.GOOGLE_BOOKS_API_KEY);
  const response = await fetch(upstream, { headers: { Accept: "application/json" } });
  const body = await response.text();

  const proxied = new Response(body, {
    status: response.status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": response.ok ? "public, max-age=86400" : "no-store",
    },
  });
  if (response.ok) ctx.waitUntil(cache.put(cacheKey, proxied.clone()));
  return proxied;
}
