import { AboutStory } from "@/components/about/AboutStory";
import { AboutValues } from "@/components/about/AboutValues";
import { CallToAction } from "@/components/reusable/CallToAction";
import { PageHero } from "@/components/reusable/PageHero";
import { Section } from "@/components/reusable/Section";
import { aboutContent, homeContent } from "@/lib/content";
import { JsonLd } from "@/components/reusable/JsonLd";
import { pageMetadata } from "@/lib/seo";
import { breadcrumbStructuredData } from "@/lib/structured-data";

export const metadata = pageMetadata({
  title: "About",
  description: aboutContent.hero.subtitle,
  path: "/about",
  keywords: ["about Mad Miners", "Mad Miners developer", "indie game Nepal"],
});

export default function AboutPage() {
  const { hero, story, values } = aboutContent;
  return (
    <>
      <JsonLd data={breadcrumbStructuredData("About", "/about")} />
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
