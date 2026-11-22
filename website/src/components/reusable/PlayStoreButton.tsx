import { Play } from "lucide-react";

import { site } from "@/lib/content";
import { cn } from "@/lib/utils";

type PlayStoreButtonProps = {
  className?: string;
  /** "dark" on light backgrounds, "light" on the dark gallery band. */
  tone?: "dark" | "light";
};

/** Store badge: two-line "Get it on / Google Play", like the real thing. */
export function PlayStoreButton({ className, tone = "dark" }: PlayStoreButtonProps) {
  return (
    <a
      href={site.playStoreUrl}
      target="_blank"
      rel="noopener noreferrer"
      aria-label="Get Mad Miners on Google Play"
      className={cn(
        "inline-flex h-12 items-center gap-3 rounded-[10px] px-4 transition-colors",
        tone === "dark" ? "bg-ink hover:bg-ink/90 text-white" : "text-ink bg-white hover:bg-white/90",
        className,
      )}
    >
      <Play aria-hidden className="size-5 fill-current" strokeWidth={0} />
      <span className="flex flex-col leading-none">
        <span className="text-[0.625rem] font-medium tracking-wider uppercase opacity-80">Get it on</span>
        <span className="mt-0.5 text-[1.0625rem] font-semibold">Google Play</span>
      </span>
    </a>
  );
}
