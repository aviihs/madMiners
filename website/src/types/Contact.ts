import type { IconName } from "@/lib/icons";

import type { PageHeroContent } from "./Content";

export type ContactChannel = {
  icon: IconName;
  title: string;
  text: string;
  kind: "email" | "deletion" | "privacy";
};

export type ContactContent = {
  hero: PageHeroContent;
  channels: ContactChannel[];
  form: { title: string; note: string; topics: string[]; submit: string };
};
