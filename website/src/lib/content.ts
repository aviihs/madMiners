import aboutJson from "@/data/about.json";
import contactJson from "@/data/contact.json";
import deleteAccountJson from "@/data/delete-account.json";
import homeJson from "@/data/home.json";
import privacyPolicyJson from "@/data/privacy-policy.json";
import siteJson from "@/data/site.json";
import type { AboutContent } from "@/types/About";
import type { ContactContent } from "@/types/Contact";
import type { HomeContent } from "@/types/Home";
import type { DeleteAccountContent, PrivacyPolicyContent } from "@/types/PrivacyPolicy";
import type { Site } from "@/types/Site";

/**
 * Typed access to the JSON content in `src/data`. Pages read content from
 * here, never from the JSON files directly, so the types are checked once.
 */
export const site: Site = siteJson;
export const homeContent = homeJson as HomeContent;
export const aboutContent = aboutJson as AboutContent;
export const contactContent = contactJson as ContactContent;
export const privacyPolicyContent = privacyPolicyJson as PrivacyPolicyContent;
export const deleteAccountContent = deleteAccountJson as DeleteAccountContent;

/** Fills `{email}`, `{developer}` and `{location}` placeholders in content. */
export function fillPlaceholders(text: string): string {
  return text
    .replaceAll("{email}", site.contactEmail)
    .replaceAll("{developer}", site.developer)
    .replaceAll("{location}", site.location);
}

/** "2026-11-21" → "21 November 2026". */
export function formatDate(isoDate: string): string {
  return new Date(`${isoDate}T00:00:00Z`).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  });
}
