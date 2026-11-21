import { site } from "@/lib/content";
import { SITE_URL } from "@/lib/seo";
import type { FaqItem } from "@/types/Content";

/** schema.org description of the game, for search engines. */
export function gameStructuredData() {
  return {
    "@context": "https://schema.org",
    "@type": "VideoGame",
    name: site.storeTitle,
    description: site.description,
    url: SITE_URL,
    image: `${SITE_URL}/screenshots/deep-mine.jpg`,
    genre: ["Arcade", "Action", "Multiplayer"],
    playMode: ["MultiPlayer", "SinglePlayer"],
    gamePlatform: "Android",
    applicationCategory: "Game",
    operatingSystem: "Android",
    offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
    author: { "@type": "Organization", name: site.developer },
    installUrl: site.playStoreUrl,
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
