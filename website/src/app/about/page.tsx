import { AboutStory } from "@/components/about/AboutStory";
import { CallToAction } from "@/components/reusable/CallToAction";
import { IconCardGrid } from "@/components/reusable/IconCardGrid";
import { PageHero } from "@/components/reusable/PageHero";
import { Section } from "@/components/reusable/Section";
import { SectionIntro } from "@/components/reusable/SectionIntro";
import { aboutContent, homeContent } from "@/lib/content";
import { pageMetadata } from "@/lib/seo";

export const metadata = pageMetadata({
  title: "About",
  description: aboutContent.hero.subtitle,
  path: "/about",
});

export default function AboutPage() {
  const { hero, story, values } = aboutContent;
  return (
    <>
      <PageHero {...hero} />
      <Section>
        <AboutStory story={story} />
      </Section>
      <Section className="pt-0 sm:pt-0">
        <SectionIntro title={values.title} />
        <IconCardGrid items={values.items} columns={4} />
      </Section>
      <CallToAction {...homeContent.cta} />
    </>
  );
}
