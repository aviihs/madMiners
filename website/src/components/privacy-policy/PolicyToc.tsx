"use client";

import { useActiveSection } from "@/hooks/use-active-section";
import { cn } from "@/lib/utils";

type PolicyTocProps = {
  sections: { id: string; title: string }[];
};

/**
 * "On this page" list that stays in view while you scroll and marks the section
 * you're reading. `self-start` matters: a stretched grid item can't stick.
 */
export function PolicyToc({ sections }: PolicyTocProps) {
  const activeId = useActiveSection(sections.map((section) => section.id));
  return (
    <nav
      aria-label="On this page"
      className="sticky top-24 hidden max-h-[calc(100dvh-7rem)] self-start overflow-y-auto overscroll-contain lg:block"
    >
      <p className="text-ink-muted text-[0.8125rem] font-semibold tracking-wide">On this page</p>
      <ol className="mt-3 space-y-0.5">
        {sections.map((section, index) => (
          <li key={section.id}>
            <a
              href={`#${section.id}`}
              className={cn(
                "flex gap-2 rounded-md px-2 py-1.5 text-[0.875rem] transition-colors",
                activeId === section.id
                  ? "bg-paper-deep text-ink font-semibold"
                  : "text-ink-soft hover:text-ink",
              )}
            >
              <span className="text-ink-muted w-5 shrink-0 tabular-nums">{index + 1}.</span>
              {section.title}
            </a>
          </li>
        ))}
      </ol>
    </nav>
  );
}
