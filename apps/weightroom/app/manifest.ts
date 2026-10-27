import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "GYMU | Sala de Musculación UTFSM Concepción",
    short_name: "GYMU",
    description: "Gestión de la Sala de Musculación UTFSM Concepción",
    id: "/",
    start_url: "/",
    scope: "/",
    display: "standalone",
    background_color: "#000000",
    theme_color: "#000000",
    icons: [
      {
        src: "/pwa/icon-192.png",
        sizes: "192x192",
        type: "image/png",
        purpose: "any",
      },
      {
        src: "/pwa/icon-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
    lang: "es-CL",
    categories: ["health", "fitness"],
  };
}
