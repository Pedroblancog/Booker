# Backend de Booker

Un Cloudflare Worker mínimo. Es el único sitio donde viven las claves de API:
la app nunca las ve.

| Ruta | Qué hace |
|---|---|
| `GET /health` | Dice qué está configurado. No necesita token. |
| `GET /books/v1/volumes?q=…` | Reenvía la búsqueda a Google Books añadiendo `GOOGLE_BOOKS_API_KEY`. |
| `POST /recommendations` | Pide recomendaciones a un modelo de IA y devuelve JSON. |

Las recomendaciones salen, por orden de preferencia, de:

1. **Claude** (`claude-opus-5-5`), si existe el secreto `ANTHROPIC_API_KEY`. De pago por uso.
2. **Workers AI** (`WORKERS_AI_MODEL` en `wrangler.toml`, ahora `@cf/openai/gpt-oss-120b`).
   Gratis dentro de la cuota diaria del plan Free de Cloudflare. Es lo que se usa por defecto.

`POST /recommendations` recibe:

```json
{
  "favorites": [{ "title": "Pedro Páramo", "authors": ["Juan Rulfo"], "rating": 5 }],
  "exclude": ["Rayuela — Julio Cortázar"],
  "count": 3
}
```

y responde `{ "recommendations": [{ "title", "author", "reason" }] }`.
La app verifica después cada libro contra Google Books / Open Library y pide
otro si alguno no existe.

## Probar en local

```bash
npm install
cp .dev.vars.example .dev.vars
npm run dev
```

Con `MOCK_RECOMMENDATIONS=true` y sin clave de Anthropic devuelve
recomendaciones de ejemplo; la primera es un libro inventado, para comprobar
que la app lo descarta. La app en Debug usa `http://localhost:8787`.

## Desplegar

1. Crea una cuenta gratuita en Cloudflare e inicia sesión:
   ```bash
   npx wrangler login
   ```
2. Guarda los secretos (te pedirá cada valor):
   ```bash
   npx wrangler secret put GOOGLE_BOOKS_API_KEY
   npx wrangler secret put APP_TOKEN
   ```
   - `GOOGLE_BOOKS_API_KEY`: en Google Cloud Console, activa "Books API" y crea una clave restringida a esa API. Gratuita.
   - `APP_TOKEN`: un texto largo y aleatorio. Evita que cualquiera use tu backend.
   - Opcional y de pago: `npx wrangler secret put ANTHROPIC_API_KEY` para usar Claude en vez de Workers AI.
3. Despliega:
   ```bash
   npm run deploy
   ```
4. En la app, copia `Booker/Config/Secrets.example.xcconfig` como
   `Secrets.xcconfig` y pon la URL que te dio el despliegue y el mismo `APP_TOKEN`.

## Notas

- El `APP_TOKEN` viaja dentro de la app, así que no es un secreto fuerte: solo
  frena usos casuales. Para limitar abusos de verdad, añade una regla de
  limitación de peticiones en el panel de Cloudflare.
- Si Claude rechaza una petición por sus filtros de seguridad, la API la repite
  automáticamente con el modelo alternativo recomendado (`fallbacks: "default"`).
