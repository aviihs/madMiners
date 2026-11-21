import type { MetadataRoute } from "next";

import { site } from "@/lib/content";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: site.storeTitle,
    short_name: site.name,
    description: site.description,
    start_url: "/",
    display: "standalone",
    background_color: "#0c0a14",
    theme_color: "#0c0a14",
    icons: [{ src: "/icon.png", sizes: "512x512", type: "image/png" }],
  };
}
