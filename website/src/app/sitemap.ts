import type { MetadataRoute } from "next";

import { site } from "@/lib/content";
import { SITE_URL } from "@/lib/seo";

const PAGES: { path: string; priority: number }[] = [
  { path: "/", priority: 1 },
  { path: "/about", priority: 0.6 },
  { path: "/contact", priority: 0.6 },
  { path: "/privacy-policy", priority: 0.8 },
  { path: "/delete-account", priority: 0.5 },
];

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date(`${site.policyLastUpdated}T00:00:00Z`);
  return PAGES.map(({ path, priority }) => ({ url: `${SITE_URL}${path}`, lastModified, priority }));
}
