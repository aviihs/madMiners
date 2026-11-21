"use client";

import { useActiveSection } from "@/hooks/use-active-section";
import { cn } from "@/lib/utils";

type PolicyTocProps = {
  sections: { id: string; title: string }[];
};

/** Sticky "On this page" list that highlights the section you're reading. */
export function PolicyToc({ sections }: PolicyTocProps) {
  const activeId = useActiveSection(sections.map((section) => section.id));
  return (
    <nav aria-label="On this page" className="sticky top-28 hidden lg:block">
      <p className="font-display text-faint tracking-[0.15em] uppercase">On this page</p>
      <ol className="border-hairline mt-4 space-y-1 border-l">
        {sections.map((section) => (
          <li key={section.id}>
            <a
              href={`#${section.id}`}
              className={cn(
                "-ml-px block border-l-2 py-1.5 pl-4 text-sm transition",
                activeId === section.id
                  ? "border-gold text-gold font-extrabold"
                  : "text-muted hover:text-text border-transparent",
              )}
            >
              {section.title}
            </a>
          </li>
        ))}
      </ol>
    </nav>
  );
}
