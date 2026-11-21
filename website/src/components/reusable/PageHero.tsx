import type { PageHeroContent } from "@/types/Content";

type PageHeroProps = PageHeroContent & {
  /** Extra line under the subtitle (e.g. "Last updated …"). */
  note?: string;
};

/** Heading block at the top of inner pages. */
export function PageHero({ eyebrow, title, subtitle, note }: PageHeroProps) {
  return (
    <header className="relative overflow-hidden border-b border-hairline">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(60%_80%_at_50%_0%,rgb(155_107_255/0.28),transparent)]" />
      <div className="relative mx-auto max-w-3xl px-5 pt-36 pb-16 text-center sm:px-8 sm:pt-44">
        <p className="font-display text-sm tracking-[0.2em] text-gold uppercase">{eyebrow}</p>
        <h1 className="mt-4 text-4xl sm:text-6xl">{title}</h1>
        <p className="mt-5 text-lg text-muted">{subtitle}</p>
        {note && <p className="mt-6 text-sm text-faint">{note}</p>}
      </div>
    </header>
  );
}
