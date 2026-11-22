import { AboutStory } from "@/components/about/AboutStory";
import { AboutValues } from "@/components/about/AboutValues";
import { CallToAction } from "@/components/reusable/CallToAction";
import { PageHero } from "@/components/reusable/PageHero";
import { Section } from "@/components/reusable/Section";
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
      <Section className="pt-0 md:pt-0">
        <AboutValues values={values} />
      </Section>
      <CallToAction title={homeContent.cta.title} subtitle={homeContent.cta.subtitle} />
    </>
  );
}
