import { ContactChannels } from "@/components/contact/ContactChannels";
import { ContactForm } from "@/components/contact/ContactForm";
import { PageHero } from "@/components/reusable/PageHero";
import { Section } from "@/components/reusable/Section";
import { contactContent } from "@/lib/content";
import { pageMetadata } from "@/lib/seo";

export const metadata = pageMetadata({
  title: "Contact",
  description: contactContent.hero.subtitle,
  path: "/contact",
});

export default function ContactPage() {
  const { hero, channels, form } = contactContent;
  return (
    <>
      <PageHero {...hero} />
      <Section className="grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
        <ContactChannels channels={channels} />
        <ContactForm form={form} />
      </Section>
    </>
  );
}
