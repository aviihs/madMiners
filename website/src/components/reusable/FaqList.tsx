import { ChevronDown } from "lucide-react";

import type { FaqItem } from "@/types/Content";

/** Accordion built on <details>: accessible and needs no JavaScript. */
export function FaqList({ items }: { items: FaqItem[] }) {
  return (
    <div className="divide-hairline border-hairline bg-surface/60 mx-auto max-w-3xl divide-y overflow-hidden rounded-3xl border">
      {items.map((item) => (
        <details key={item.question} className="group px-6 py-5">
          <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-lg font-extrabold">
            {item.question}
            <ChevronDown aria-hidden className="text-gold size-5 shrink-0 transition group-open:rotate-180" />
          </summary>
          <p className="text-muted mt-3">{item.answer}</p>
        </details>
      ))}
    </div>
  );
}
