import { ChevronDown } from "lucide-react";

import type { FaqItem } from "@/types/Content";

/** Accordion built on <details>: accessible and needs no JavaScript. */
export function FaqList({ items }: { items: FaqItem[] }) {
  return (
    <div className="mx-auto max-w-3xl divide-y divide-hairline overflow-hidden rounded-3xl border border-hairline bg-surface/60">
      {items.map((item) => (
        <details key={item.question} className="group px-6 py-5">
          <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-lg font-extrabold">
            {item.question}
            <ChevronDown aria-hidden className="size-5 shrink-0 text-gold transition group-open:rotate-180" />
          </summary>
          <p className="mt-3 text-muted">{item.answer}</p>
        </details>
      ))}
    </div>
  );
}
