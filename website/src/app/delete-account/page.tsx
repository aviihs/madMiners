import { Check, Info, X } from "lucide-react";

import { PageHero } from "@/components/reusable/PageHero";
import { Section } from "@/components/reusable/Section";
import { deleteAccountContent, fillPlaceholders, site } from "@/lib/content";
import { buildMailto } from "@/lib/mailto";
import { pageMetadata } from "@/lib/seo";

export const metadata = pageMetadata({
  title: "Delete your account",
  description: `How to delete your ${site.name} account and all of its game data.`,
  path: "/delete-account",
});

const DELETION_MAILTO = buildMailto({
  to: site.contactEmail,
  subject: "Delete my account",
  body: "Please delete my Mad Miners account and its data.\n\nIn-game username: ",
});

export default function DeleteAccountPage() {
  const { hero, steps, deleted, kept, deviceNote } = deleteAccountContent;
  return (
    <>
      <PageHero {...hero} />
      <Section className="max-w-4xl">
        <ol className="space-y-4">
          {steps.map((step, index) => (
            <li key={step.title} className="border-hairline bg-surface/70 flex gap-5 rounded-3xl border p-6">
              <span className="bg-gold font-display text-on-gold flex size-11 shrink-0 items-center justify-center rounded-full text-xl">
                {index + 1}
              </span>
              <div>
                <h2 className="text-2xl">{step.title}</h2>
                <p className="text-muted mt-1">{fillPlaceholders(step.text)}</p>
              </div>
            </li>
          ))}
        </ol>

        <div className="mt-8 text-center">
          <a
            href={DELETION_MAILTO}
            className="bg-lava font-display inline-flex rounded-2xl px-6 py-3.5 text-lg text-white transition hover:brightness-110"
          >
            Email a deletion request
          </a>
        </div>

        <div className="mt-12 grid gap-5 sm:grid-cols-2">
          <ListCard title={deleted.title} items={deleted.items} isDeleted />
          <ListCard title={kept.title} items={kept.items} />
        </div>

        <p className="border-sky/25 bg-sky/10 text-muted mt-8 flex gap-3 rounded-3xl border p-5">
          <Info aria-hidden className="text-sky mt-0.5 size-5 shrink-0" />
          {deviceNote}
        </p>
      </Section>
    </>
  );
}

function ListCard({
  title,
  items,
  isDeleted = false,
}: {
  title: string;
  items: string[];
  isDeleted?: boolean;
}) {
  const Icon = isDeleted ? X : Check;
  return (
    <section className="border-hairline bg-surface/70 rounded-3xl border p-6">
      <h2 className="text-2xl">{title}</h2>
      <ul className="text-muted mt-4 space-y-3">
        {items.map((item) => (
          <li key={item} className="flex gap-3">
            <Icon
              aria-hidden
              className={`mt-1 size-4 shrink-0 ${isDeleted ? "text-lava" : "text-leaf"}`}
              strokeWidth={3}
            />
            {item}
          </li>
        ))}
      </ul>
    </section>
  );
}
