import { Reveal } from "@/components/motion/Reveal";
import { cn } from "@/lib/utils";
import type { IconCard } from "@/types/Content";

import { IconBadge } from "./IconBadge";

type IconCardGridProps = {
  items: IconCard[];
  columns?: 2 | 3 | 4;
};

const COLUMN_CLASSES = {
  2: "sm:grid-cols-2",
  3: "sm:grid-cols-2 lg:grid-cols-3",
  4: "sm:grid-cols-2 lg:grid-cols-4",
};

/** Grid of icon + title + text cards (features, values, highlights). */
export function IconCardGrid({ items, columns = 3 }: IconCardGridProps) {
  return (
    <div className={cn("grid gap-5", COLUMN_CLASSES[columns])}>
      {items.map((item, index) => (
        <Reveal key={item.title} delay={index * 70}>
          <article className="border-hairline bg-surface/70 hover:border-gold/30 hover:bg-surface-high/70 h-full rounded-3xl border p-6 transition hover:-translate-y-1">
            <IconBadge icon={item.icon} tone={item.tone} />
            <h3 className="mt-5 text-2xl">{item.title}</h3>
            <p className="text-muted mt-2">{item.text}</p>
          </article>
        </Reveal>
      ))}
    </div>
  );
}
