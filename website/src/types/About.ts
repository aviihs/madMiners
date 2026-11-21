import type { IconCard, PageHeroContent } from "./Content";

export type AboutContent = {
  hero: PageHeroContent;
  story: { title: string; paragraphs: string[] };
  values: { title: string; items: IconCard[] };
};
