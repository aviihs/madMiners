import type { MetadataRoute } from "next";

import { homeContent, site } from "@/lib/content";
import { absoluteUrl } from "@/lib/seo";

type Page = {
  path: string;
  priority: number;
  changeFrequency: NonNullable<MetadataRoute.Sitemap[number]["changeFrequency"]>;
  images?: string[];
};

const PAGES: Page[] = [
  {
    path: "/",
    priority: 1,
    changeFrequency: "weekly",
    // Image sitemap: lets the screenshots show up in image search.
    images: homeContent.screenshots.items.map((shot) => absoluteUrl(shot.src)),
  },
  { path: "/about", priority: 0.7, changeFrequency: "monthly" },
  { path: "/privacy-policy", priority: 0.6, changeFrequency: "monthly" },
  { path: "/contact", priority: 0.5, changeFrequency: "yearly" },
  { path: "/delete-account", priority: 0.4, changeFrequency: "yearly" },
];

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date(`${site.policyLastUpdated}T00:00:00Z`);
  return PAGES.map(({ path, priority, changeFrequency, images }) => ({
    url: absoluteUrl(path),
    lastModified,
    changeFrequency,
    priority,
    ...(images && { images }),
  }));
}
