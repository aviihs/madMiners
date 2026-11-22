import type { Metadata } from "next";

import { site } from "@/lib/content";

/**
 * Base URL of the deployed site, used for canonical links, the sitemap,
 * structured data and social cards. Set NEXT_PUBLIC_SITE_URL in production;
 * on Vercel the production domain is picked up automatically.
 */
export const SITE_URL = (
  process.env.NEXT_PUBLIC_SITE_URL ??
  (process.env.VERCEL_PROJECT_PRODUCTION_URL
    ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
    : "http://localhost:3000")
).replace(/\/$/, "");

/** Absolute URL for a site path ("/about" → "https://…/about"). */
export const absoluteUrl = (path: string) => `${SITE_URL}${path === "/" ? "" : path}`;

type PageMetadataInput = {
  title: string;
  description: string;
  path: string;
  /** Extra search phrases for this page, on top of the site-wide ones. */
  keywords?: string[];
};

/** Consistent title, description, canonical URL and social cards for a page. */
export function pageMetadata({ title, description, path, keywords }: PageMetadataInput): Metadata {
  return {
    title,
    description,
    keywords: keywords ? [...keywords, ...site.keywords] : undefined,
    alternates: { canonical: path },
    openGraph: {
      title: `${title} · ${site.name}`,
      description,
      url: path,
      siteName: site.name,
      type: "website",
      locale: "en_US",
    },
    twitter: { card: "summary_large_image", title: `${title} · ${site.name}`, description },
  };
}
