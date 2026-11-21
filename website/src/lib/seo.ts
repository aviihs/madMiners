import type { Metadata } from "next";

import { site } from "@/lib/content";

/** Base URL of the deployed site (set NEXT_PUBLIC_SITE_URL in production). */
export const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000").replace(/\/$/, "");

type PageMetadataInput = {
  title: string;
  description: string;
  path: string;
};

/** Consistent title, description, canonical URL and social cards for a page. */
export function pageMetadata({ title, description, path }: PageMetadataInput): Metadata {
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title: `${title} · ${site.name}`,
      description,
      url: path,
      siteName: site.name,
      type: "website",
    },
    twitter: { card: "summary_large_image", title: `${title} · ${site.name}`, description },
  };
}
