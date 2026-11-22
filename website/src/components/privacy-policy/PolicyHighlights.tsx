import { Check } from "lucide-react";

import type { IconCard } from "@/types/Content";

/** "At a glance" summary box above the full policy. */
export function PolicyHighlights({ items }: { items: IconCard[] }) {
  return (
    <aside aria-label="Summary" className="border-line bg-card shadow-card rounded-2xl border p-6 sm:p-7">
      <h2 className="text-ink-muted font-sans text-[0.8125rem] font-semibold tracking-wide">At a glance</h2>
      <ul className="mt-4 grid gap-x-8 gap-y-4 sm:grid-cols-2">
        {items.map((item) => (
          <li key={item.title} className="flex gap-3">
            <Check aria-hidden className="text-ok mt-1 size-4 shrink-0" strokeWidth={2.5} />
            <p className="text-ink-soft text-[0.9375rem]">
              <strong className="text-ink font-semibold">{item.title}.</strong> {item.text}
            </p>
          </li>
        ))}
      </ul>
    </aside>
  );
}
