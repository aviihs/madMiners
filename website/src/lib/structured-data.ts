import { homeContent, site } from "@/lib/content";
import { absoluteUrl, SITE_URL } from "@/lib/seo";
import type { FaqItem } from "@/types/Content";

/**
 * schema.org data for search engines (and AI assistants that read it).
 * Only facts that are true: no invented ratings, reviews or download counts.
 */

const ORG_ID = `${SITE_URL}/#organization`;
const SITE_ID = `${SITE_URL}/#website`;
const GAME_ID = `${SITE_URL}/#game`;

const sameAs = Object.values(site.social).filter((url) => url.trim() !== "");

export function organizationStructuredData() {
  return {
    "@context": "https://schema.org",
    "@type": "Organization",
    "@id": ORG_ID,
    name: site.developer,
    url: SITE_URL,
    logo: absoluteUrl("/icon.png"),
    email: site.contactEmail,
    address: { "@type": "PostalAddress", addressLocality: "Kathmandu", addressCountry: "NP" },
    sameAs,
  };
}

export function websiteStructuredData() {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "@id": SITE_ID,
    name: site.name,
    alternateName: [site.storeTitle, "Mad Miners game"],
    url: SITE_URL,
    description: site.seoDescription,
    inLanguage: "en",
    publisher: { "@id": ORG_ID },
  };
}

/** The game itself: a VideoGame that is also an installable Android app. */
export function gameStructuredData() {
  const screenshots = homeContent.screenshots.items.map((shot) => absoluteUrl(shot.src));
  return {
    "@context": "https://schema.org",
    "@type": ["VideoGame", "MobileApplication"],
    "@id": GAME_ID,
    name: site.storeTitle,
    alternateName: site.name,
    description: site.description,
    url: SITE_URL,
    image: screenshots[0],
    screenshot: screenshots,
    genre: site.genres,
    keywords: site.keywords.join(", "),
    playMode: ["MultiPlayer", "SinglePlayer"],
    numberOfPlayers: { "@type": "QuantitativeValue", minValue: 1, maxValue: 12 },
    gamePlatform: ["Android"],
    operatingSystem: "Android",
    applicationCategory: "GameApplication",
    applicationSubCategory: "Arcade",
    inLanguage: "en",
    isAccessibleForFree: true,
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
      url: site.playStoreUrl,
    },
    installUrl: site.playStoreUrl,
    downloadUrl: site.playStoreUrl,
    author: { "@id": ORG_ID },
    publisher: { "@id": ORG_ID },
    countryOfOrigin: { "@type": "Country", name: "Nepal" },
  };
}

export function faqStructuredData(items: FaqItem[]) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: { "@type": "Answer", text: item.answer },
    })),
  };
}

/** "Home › About" trail for inner pages. */
export function breadcrumbStructuredData(name: string, path: string) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: absoluteUrl("/") },
      { "@type": "ListItem", position: 2, name, item: absoluteUrl(path) },
    ],
  };
}
