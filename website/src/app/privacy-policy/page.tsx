import { PolicyHighlights } from "@/components/privacy-policy/PolicyHighlights";
import { PolicySection } from "@/components/privacy-policy/PolicySection";
import { PolicyToc } from "@/components/privacy-policy/PolicyToc";
import { ReadingProgress } from "@/components/privacy-policy/ReadingProgress";
import { PageHero } from "@/components/reusable/PageHero";
import { Section } from "@/components/reusable/Section";
import { formatDate, privacyPolicyContent, site } from "@/lib/content";
import { pageMetadata } from "@/lib/seo";

export const metadata = pageMetadata({
  title: "Privacy Policy",
  description: `How ${site.name} collects, uses and protects your information, and how to delete your account.`,
  path: "/privacy-policy",
});

export default function PrivacyPolicyPage() {
  const { hero, highlights, sections } = privacyPolicyContent;
  return (
    <>
      <ReadingProgress />
      <PageHero {...hero} note={`Effective ${formatDate(site.policyLastUpdated)}`} />
      <Section className="grid gap-12 lg:grid-cols-[220px_1fr] lg:gap-16">
        <PolicyToc sections={sections.map(({ id, title }) => ({ id, title }))} />
        <div className="max-w-[44rem]">
          <PolicyHighlights items={highlights} />
          <article className="mt-12 space-y-8 text-[1rem] leading-[1.75]">
            {sections.map((section, index) => (
              <PolicySection key={section.id} section={section} number={index + 1} />
            ))}
          </article>
        </div>
      </Section>
    </>
  );
}
