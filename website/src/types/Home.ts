import type { FaqItem, IconCard, Step } from "./Content";

export type Screenshot = {
  src: string;
  alt: string;
  caption: string;
};

export type HomeContent = {
  hero: {
    eyebrow: string;
    title: string;
    subtitle: string;
    primaryCta: string;
    secondaryCta: string;
    badges: string[];
  };
  stats: { value: string; label: string }[];
  features: { title: string; subtitle: string; items: IconCard[] };
  screenshots: { title: string; subtitle: string; items: Screenshot[] };
  steps: { title: string; items: Step[] };
  fairPlay: { title: string; items: IconCard[] };
  faq: { title: string; items: FaqItem[] };
  cta: { title: string; subtitle: string; button: string };
};
