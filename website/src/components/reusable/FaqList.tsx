import { Plus } from "lucide-react";

import type { FaqItem } from "@/types/Content";

/** Accordion built on <details>: accessible and needs no JavaScript. */
export function FaqList({ items }: { items: FaqItem[] }) {
  return (
    <div className="border-line border-t">
      {items.map((item) => (
        <details key={item.question} className="group border-line border-b">
          <summary className="text-ink flex cursor-pointer list-none items-start justify-between gap-6 py-5 text-[1.0625rem] font-semibold [&::-webkit-details-marker]:hidden">
            {item.question}
            <Plus
              aria-hidden
              className="text-ink-muted mt-1 size-4 shrink-0 transition-transform duration-200 group-open:rotate-45"
            />
          </summary>
          <p className="text-ink-soft -mt-1 max-w-2xl pb-5">{item.answer}</p>
        </details>
      ))}
    </div>
  );
}
