import { ICONS } from "@/lib/icons";
import type { IconCard } from "@/types/Content";

/**
 * "At a glance": four promise cards that sit across the bottom edge of the
 * page header. A swipe row on phones, 2 columns on tablets, 4 on desktop.
 */
export function PolicyHighlights({ items }: { items: IconCard[] }) {
  return (
    <section aria-label="At a glance" className="relative mx-auto -mt-14 max-w-6xl px-5 sm:-mt-16 sm:px-8">
      <ul className="swipe-row grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {items.map((item) => {
          const Icon = ICONS[item.icon];
          return (
            <li
              key={item.title}
              className="interactive-card border-line bg-card shadow-raised rounded-3xl border p-6"
            >
              <span className="from-accent to-accent-ink mb-5 flex size-11 items-center justify-center rounded-2xl bg-linear-to-br text-white shadow-[0_8px_18px_-8px_rgb(143_90_7/0.7)]">
                <Icon aria-hidden className="size-5" strokeWidth={2} />
              </span>
              <h2 className="text-ink font-sans text-[1rem] font-semibold tracking-tight">{item.title}</h2>
              <p className="text-ink-soft mt-1.5 text-[0.875rem] leading-relaxed">{item.text}</p>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
