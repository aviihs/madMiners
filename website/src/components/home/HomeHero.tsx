import { Check } from "lucide-react";
import Image from "next/image";

import { PlayStoreButton } from "@/components/reusable/PlayStoreButton";
import type { HomeContent } from "@/types/Home";

/** Landing hero: headline, Play button and the miner crew. */
export function HomeHero({ hero }: { hero: HomeContent["hero"] }) {
  return (
    <section className="relative overflow-hidden">
      {/* Underground mood: violet glow above, lava glow below. */}
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(70%_60%_at_50%_0%,rgb(155_107_255/0.35),transparent),radial-gradient(60%_40%_at_50%_100%,rgb(255_106_61/0.22),transparent)]" />
      <div className="relative mx-auto grid max-w-6xl items-center gap-10 px-5 pt-32 pb-16 sm:px-8 sm:pt-40 lg:grid-cols-[1.05fr_1fr] lg:pb-24">
        <div className="text-center lg:text-left">
          <p className="inline-flex rounded-full border border-gold/30 bg-gold/10 px-4 py-1.5 font-display text-sm tracking-[0.15em] text-gold uppercase">
            {hero.eyebrow}
          </p>
          <h1 className="mt-6 text-5xl sm:text-7xl">
            <span className="bg-gradient-to-b from-gold-light to-gold bg-clip-text text-transparent">{hero.title}</span>
          </h1>
          <p className="mx-auto mt-6 max-w-xl text-lg text-muted lg:mx-0">{hero.subtitle}</p>
          <div className="mt-9 flex flex-wrap items-center justify-center gap-5 lg:justify-start">
            <PlayStoreButton label={hero.primaryCta} />
            <a href="#features" className="rounded-2xl px-5 py-3.5 font-extrabold text-text underline-offset-4 hover:underline">
              {hero.secondaryCta} →
            </a>
          </div>
          <ul className="mt-8 flex flex-wrap justify-center gap-x-6 gap-y-2 text-sm text-muted lg:justify-start">
            {hero.badges.map((badge) => (
              <li key={badge} className="flex items-center gap-1.5">
                <Check aria-hidden className="size-4 text-leaf" strokeWidth={3} />
                {badge}
              </li>
            ))}
          </ul>
        </div>
        <div className="relative">
          <div className="absolute inset-x-10 top-1/4 h-1/2 animate-glow rounded-full bg-gold/25 blur-3xl" />
          <Image
            src="/art/miners.png"
            alt="Three Mad Miners characters: a bearded veteran with an axe, a miner flying with a jetpack, and a robot with a drill"
            width={1200}
            height={720}
            priority
            sizes="(min-width: 1024px) 560px, 92vw"
            className="relative w-full animate-float"
          />
        </div>
      </div>
    </section>
  );
}
