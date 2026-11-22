import { Check, Info, X } from "lucide-react";

import { PageHero } from "@/components/reusable/PageHero";
import { Section } from "@/components/reusable/Section";
import { deleteAccountContent, fillPlaceholders, site } from "@/lib/content";
import { buildMailto } from "@/lib/mailto";
import { pageMetadata } from "@/lib/seo";
import { cn } from "@/lib/utils";

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
      <Section className="grid gap-12 lg:grid-cols-[1.1fr_0.9fr] lg:gap-16">
        <div>
          <h2 className="text-[1.5rem]">How to request deletion</h2>
          <ol className="mt-6 space-y-6">
            {steps.map((step, index) => (
              <li key={step.title} className="grid grid-cols-[2rem_1fr] gap-4">
                <span className="border-line-strong bg-card flex size-8 items-center justify-center rounded-full border text-[0.875rem] font-semibold tabular-nums">
                  {index + 1}
                </span>
                <div>
                  <h3 className="text-[1.125rem]">{step.title}</h3>
                  <p className="text-ink-soft mt-1">{fillPlaceholders(step.text)}</p>
                </div>
              </li>
            ))}
          </ol>
          <a
            href={DELETION_MAILTO}
            className="bg-danger hover:bg-danger/90 mt-8 inline-flex rounded-lg px-5 py-2.5 text-[0.9375rem] font-semibold text-white transition-colors"
          >
            Email a deletion request
          </a>
          <p className="border-line bg-paper-deep/60 text-ink-soft mt-8 flex gap-3 rounded-xl border p-4 text-[0.9375rem]">
            <Info aria-hidden className="text-ink-muted mt-0.5 size-4 shrink-0" />
            {deviceNote}
          </p>
        </div>
        <div className="space-y-5">
          <ListCard title={deleted.title} items={deleted.items} isDeleted />
          <ListCard title={kept.title} items={kept.items} />
        </div>
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
    <section className="border-line bg-card shadow-card rounded-2xl border p-6">
      <h2 className="text-[1.125rem]">{title}</h2>
      <ul className="text-ink-soft mt-4 space-y-3 text-[0.9375rem]">
        {items.map((item) => (
          <li key={item} className="flex gap-3">
            <Icon
              aria-hidden
              className={cn("mt-1 size-4 shrink-0", isDeleted ? "text-danger" : "text-ok")}
              strokeWidth={2.5}
            />
            {item}
          </li>
        ))}
      </ul>
    </section>
  );
}
