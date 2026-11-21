import { FaqList } from "@/components/reusable/FaqList";
import { CallToAction } from "@/components/reusable/CallToAction";
import { HomeHero } from "@/components/home/HomeHero";
import { ScreenshotShowcase } from "@/components/home/ScreenshotShowcase";
import { StatsStrip } from "@/components/home/StatsStrip";
import { StepsSection } from "@/components/home/StepsSection";
import { IconCardGrid } from "@/components/reusable/IconCardGrid";
import { JsonLd } from "@/components/reusable/JsonLd";
import { Section } from "@/components/reusable/Section";
import { SectionIntro } from "@/components/reusable/SectionIntro";
import { homeContent } from "@/lib/content";
import { faqStructuredData, gameStructuredData } from "@/lib/structured-data";

export default function HomePage() {
  const { hero, stats, features, screenshots, steps, fairPlay, faq, cta } = homeContent;
  return (
    <>
      <JsonLd data={gameStructuredData()} />
      <JsonLd data={faqStructuredData(faq.items)} />
      <HomeHero hero={hero} />
      <StatsStrip stats={stats} />

      <Section id="features">
        <SectionIntro title={features.title} subtitle={features.subtitle} />
        <IconCardGrid items={features.items} />
      </Section>

      <Section id="screenshots" className="pt-0 sm:pt-0">
        <SectionIntro title={screenshots.title} subtitle={screenshots.subtitle} />
        <ScreenshotShowcase items={screenshots.items} />
      </Section>

      <Section id="how-it-works" className="pt-0 sm:pt-0">
        <SectionIntro title={steps.title} />
        <StepsSection items={steps.items} />
      </Section>

      <Section id="fair-play" className="pt-0 sm:pt-0">
        <SectionIntro title={fairPlay.title} />
        <IconCardGrid items={fairPlay.items} />
      </Section>

      <Section id="faq" className="pt-0 sm:pt-0">
        <SectionIntro title={faq.title} />
        <FaqList items={faq.items} />
      </Section>

      <CallToAction {...cta} />
    </>
  );
}
