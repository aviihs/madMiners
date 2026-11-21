import type { Tone } from "@/types/Content";

/** Text + soft background classes for each accent colour. */
export const TONE_CLASSES: Record<Tone, string> = {
  gold: "text-gold bg-gold/12 ring-gold/25",
  violet: "text-violet bg-violet/12 ring-violet/25",
  lava: "text-lava bg-lava/12 ring-lava/25",
  health: "text-health bg-health/12 ring-health/25",
  sky: "text-sky bg-sky/12 ring-sky/25",
  leaf: "text-leaf bg-leaf/12 ring-leaf/25",
};
