import { cn } from "@/lib/utils";
import type { PageHeroContent } from "@/types/Content";

type PageHeroProps = PageHeroContent & {
  /** Extra line under the subtitle (e.g. "Last updated …"). */
  note?: string;
  /** Extra room at the bottom for cards that overlap the header's edge. */
  overlap?: boolean;
};

/** Plain, left-aligned heading for inner pages. */
export function PageHero({ eyebrow, title, subtitle, note, overlap = false }: PageHeroProps) {
  return (
    <header className="border-line bg-paper-deep/60 border-b">
      <div
        className={cn(
          "mx-auto max-w-6xl px-5 pt-28 sm:px-8 md:pt-32",
          overlap ? "pb-24 sm:pb-28" : "pb-10 md:pb-14",
        )}
      >
        <p className="text-accent-ink text-[0.8125rem] font-semibold tracking-wide">{eyebrow}</p>
        <h1 className="mt-3 max-w-3xl text-[2.25rem] sm:text-[2.75rem]">{title}</h1>
        <p className="text-ink-soft mt-4 max-w-2xl text-[1.0625rem]">{subtitle}</p>
        {note && <p className="text-ink-muted mt-5 text-sm">{note}</p>}
      </div>
    </header>
  );
}
