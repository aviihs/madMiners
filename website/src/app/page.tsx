import Link from "next/link";

import { FactsRow } from "@/components/home/FactsRow";
import { FairPlay } from "@/components/home/FairPlay";
import { FeatureList } from "@/components/home/FeatureList";
import { HomeHero } from "@/components/home/HomeHero";
import { ScreenshotShowcase } from "@/components/home/ScreenshotShowcase";
import { StepsSection } from "@/components/home/StepsSection";
import { CallToAction } from "@/components/reusable/CallToAction";
import { FaqList } from "@/components/reusable/FaqList";
import { JsonLd } from "@/components/reusable/JsonLd";
import { Section } from "@/components/reusable/Section";
import { SectionHeader } from "@/components/reusable/SectionHeader";
import { homeContent } from "@/lib/content";
import { faqStructuredData, gameStructuredData } from "@/lib/structured-data";

export default function HomePage() {
  const { hero, stats, features, screenshots, steps, fairPlay, faq, cta } = homeContent;
  const [heroShot, ...galleryShots] = screenshots.items;
  return (
    <>
      <JsonLd data={gameStructuredData()} />
      <JsonLd data={faqStructuredData(faq.items)} />

      <HomeHero hero={hero} screenshot={heroShot} />
      <FactsRow facts={stats} />

      <Section id="features">
        <FeatureList title={features.title} description={features.subtitle} items={features.items} />
      </Section>

      <ScreenshotShowcase
        title={screenshots.title}
        description={screenshots.subtitle}
        items={[heroShot, ...galleryShots].slice(0, 3)}
      />

      <Section id="how-it-works">
        <SectionHeader label="How it plays" title={steps.title} />
        <StepsSection items={steps.items} />
      </Section>

      <Section id="fair-play" className="pt-0 md:pt-0">
        <FairPlay title={fairPlay.title} items={fairPlay.items} />
      </Section>

      <Section id="faq" className="grid gap-8 pt-0 md:pt-0 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
        <div>
          <h2 className="text-[1.75rem] sm:text-[2.25rem]">{faq.title}</h2>
          <p className="text-ink-soft mt-3">
            Can&apos;t find an answer?{" "}
            <Link
              href="/contact"
              className="text-ink decoration-line-strong hover:decoration-ink font-semibold underline underline-offset-4"
            >
              Send us a message
            </Link>
            .
          </p>
        </div>
        <FaqList items={faq.items} />
      </Section>

      <CallToAction title={cta.title} subtitle={cta.subtitle} />
    </>
  );
}
