import { Play } from "lucide-react";

import { site } from "@/lib/content";
import { cn } from "@/lib/utils";

type PlayStoreButtonProps = {
  label: string;
  className?: string;
};

/** Primary call to action: opens the Google Play listing. */
export function PlayStoreButton({ label, className }: PlayStoreButtonProps) {
  return (
    <a
      href={site.playStoreUrl}
      target="_blank"
      rel="noopener noreferrer"
      className={cn(
        "inline-flex items-center gap-3 rounded-2xl bg-gradient-to-b from-gold-light to-gold px-6 py-3.5 font-display text-lg text-on-gold shadow-[0_8px_0_var(--color-gold-deep),0_14px_30px_rgb(255_194_51/0.3)] transition hover:brightness-105 active:translate-y-1 active:shadow-[0_4px_0_var(--color-gold-deep)]",
        className,
      )}
    >
      <Play aria-hidden className="size-5 fill-current" />
      {label}
    </a>
  );
}
