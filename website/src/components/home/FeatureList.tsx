import { ICONS } from "@/lib/icons";
import type { IconCard } from "@/types/Content";

type FeatureListProps = {
  title: string;
  description: string;
  items: IconCard[];
};

/** Sticky heading on the left, numbered features on the right. */
export function FeatureList({ title, description, items }: FeatureListProps) {
  return (
    <div className="grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
      <div className="lg:sticky lg:top-28 lg:self-start">
        <p className="text-accent-ink mb-3 text-[0.8125rem] font-semibold tracking-wide">
          What&apos;s in the mine
        </p>
        <h2 className="text-[1.75rem] sm:text-[2.25rem]">{title}</h2>
        <p className="text-ink-soft mt-3 text-[1.0625rem]">{description}</p>
      </div>
      <ol className="divide-line border-line divide-y border-y">
        {items.map((item, index) => {
          const Icon = ICONS[item.icon];
          return (
            <li key={item.title} className="grid grid-cols-[2.5rem_1fr] gap-x-4 py-6 sm:grid-cols-[3rem_1fr]">
              <span className="font-heading text-ink-muted pt-0.5 text-[0.9375rem] font-semibold tabular-nums">
                {String(index + 1).padStart(2, "0")}
              </span>
              <div>
                <h3 className="flex items-center gap-2.5 text-[1.25rem]">
                  <Icon aria-hidden className="text-accent size-[1.125rem]" strokeWidth={2} />
                  {item.title}
                </h3>
                <p className="text-ink-soft mt-1.5">{item.text}</p>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
