import type { Recommendation, RecommendationRequest } from "./recommendations";

/**
 * Recomendaciones de ejemplo para desarrollo, sin clave de Anthropic.
 * La primera es inventada a propósito: sirve para comprobar que la app la
 * descarta al no encontrarla en Google Books / Open Library y pide otra.
 */
const POOL: Omit<Recommendation, "reason">[] = [
  { title: "El jardín de las horas quietas", author: "Lucía Ferrán Oyarzábal" },
  { title: "Los recuerdos del porvenir", author: "Elena Garro" },
  { title: "La invención de Morel", author: "Adolfo Bioy Casares" },
  { title: "Nada", author: "Carmen Laforet" },
  { title: "Las batallas en el desierto", author: "José Emilio Pacheco" },
  { title: "Distancia de rescate", author: "Samanta Schweblin" },
  { title: "La tregua", author: "Mario Benedetti" },
  { title: "El túnel", author: "Ernesto Sabato" },
  { title: "Rayuela", author: "Julio Cortázar" },
];

export function mockRecommendations(input: RecommendationRequest): Recommendation[] {
  const excluded = input.exclude.map(normalize);
  const anchor = input.favorites[0]?.title ?? "tus favoritos";

  return POOL.filter((book) => !excluded.some((title) => title.includes(normalize(book.title))))
    .slice(0, input.count)
    .map((book) => ({
      ...book,
      reason: `Recomendación de ejemplo: si ${anchor} te dejó huella, aquí hay una voz con la misma intensidad y otra forma de mirar.`,
    }));
}

function normalize(text: string): string {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}
