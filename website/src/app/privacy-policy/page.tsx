import { PolicySection } from "@/components/privacy-policy/PolicySection";
import { PolicyToc } from "@/components/privacy-policy/PolicyToc";
import { ReadingProgress } from "@/components/privacy-policy/ReadingProgress";
import { IconCardGrid } from "@/components/reusable/IconCardGrid";
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
      <PageHero {...hero} note={`Last updated ${formatDate(site.policyLastUpdated)}`} />
      <Section className="pb-0 sm:pb-0">
        <IconCardGrid items={highlights} columns={4} />
      </Section>
      <Section className="grid gap-12 lg:grid-cols-[240px_1fr]">
        <aside>
          <PolicyToc sections={sections.map(({ id, title }) => ({ id, title }))} />
        </aside>
        <article className="max-w-3xl text-[1.05rem] leading-relaxed">
          {sections.map((section, index) => (
            <PolicySection key={section.id} section={section} number={index + 1} />
          ))}
        </article>
      </Section>
    </>
  );
}
