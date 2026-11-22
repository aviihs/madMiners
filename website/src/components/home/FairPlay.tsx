import { ICONS } from "@/lib/icons";
import type { IconCard } from "@/types/Content";

/** Three short promises, side by side, in a quiet tinted band. */
export function FairPlay({ title, items }: { title: string; items: IconCard[] }) {
  return (
    <div className="border-line bg-card shadow-card rounded-2xl border">
      <h2 className="border-line border-b px-6 py-5 text-[1.375rem] sm:px-8">{title}</h2>
      <div className="divide-line grid divide-y md:grid-cols-3 md:divide-x md:divide-y-0">
        {items.map((item) => {
          const Icon = ICONS[item.icon];
          return (
            <div key={item.title} className="px-6 py-6 sm:px-8">
              <Icon aria-hidden className="text-accent size-5" strokeWidth={2} />
              <h3 className="mt-3 text-[1.125rem]">{item.title}</h3>
              <p className="text-ink-soft mt-1.5 text-[0.9375rem]">{item.text}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}
