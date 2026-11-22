import { PlayStoreButton } from "@/components/reusable/PlayStoreButton";
import { ScreenshotFrame } from "@/components/reusable/ScreenshotFrame";
import type { HomeContent, Screenshot } from "@/types/Home";

type HomeHeroProps = {
  hero: HomeContent["hero"];
  screenshot: Screenshot;
};

/** Landing hero: copy on the left, the real game on the right. */
export function HomeHero({ hero, screenshot }: HomeHeroProps) {
  return (
    <section className="mx-auto grid max-w-6xl items-center gap-12 px-5 pt-28 pb-12 sm:px-8 md:pt-36 md:pb-16 lg:grid-cols-[0.95fr_1.05fr] lg:gap-14">
      <div>
        <p className="text-accent-ink text-[0.8125rem] font-semibold tracking-wide">{hero.eyebrow}</p>
        <h1 className="mt-4 text-[2.5rem] sm:text-[3.25rem] lg:text-[3.5rem]">{hero.title}</h1>
        <p className="text-ink-soft mt-5 max-w-xl text-[1.125rem]">{hero.subtitle}</p>
        <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-4">
          <PlayStoreButton />
          <a
            href="#features"
            className="text-ink decoration-line-strong hover:decoration-ink text-[0.9375rem] font-semibold underline underline-offset-[6px] transition-colors"
          >
            {hero.secondaryCta}
          </a>
        </div>
        <p className="text-ink-muted mt-6 text-[0.875rem]">{hero.badges.join("  ·  ")}</p>
      </div>
      <figure>
        <ScreenshotFrame
          src={screenshot.src}
          alt={screenshot.alt}
          sizes="(min-width: 1024px) 600px, 92vw"
          priority
        />
        <figcaption className="text-ink-muted mt-3 text-center text-[0.8125rem]">
          {screenshot.caption}
        </figcaption>
      </figure>
    </section>
  );
}
