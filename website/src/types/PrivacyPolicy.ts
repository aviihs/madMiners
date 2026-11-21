import type { IconCard, PageHeroContent } from "./Content";

export type PolicyBlock =
  { type: "paragraph"; text: string } | { type: "heading"; text: string } | { type: "list"; items: string[] };

export type PolicySectionContent = {
  id: string;
  title: string;
  blocks: PolicyBlock[];
};

export type PrivacyPolicyContent = {
  hero: PageHeroContent;
  highlights: IconCard[];
  sections: PolicySectionContent[];
};

export type DeleteAccountContent = {
  hero: PageHeroContent;
  steps: { title: string; text: string }[];
  deleted: { title: string; items: string[] };
  kept: { title: string; items: string[] };
  deviceNote: string;
};
