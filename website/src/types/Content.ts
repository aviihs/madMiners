import type { IconName } from "@/lib/icons";

/** Accent colours from the game's palette. */
export type Tone = "gold" | "violet" | "lava" | "health" | "sky" | "leaf";

export type PageHeroContent = {
  eyebrow: string;
  title: string;
  subtitle: string;
};

export type IconCard = {
  icon: IconName;
  title: string;
  text: string;
  tone?: Tone;
};

export type Step = {
  title: string;
  text: string;
};

export type FaqItem = {
  question: string;
  answer: string;
};
