import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

type SectionProps = {
  children: ReactNode;
  id?: string;
  className?: string;
};

/** Page section with the shared max width and side padding. */
export function Section({ children, id, className }: SectionProps) {
  return (
    <section id={id} className={cn("mx-auto w-full max-w-6xl scroll-mt-24 px-5 py-16 sm:px-8 sm:py-24", className)}>
      {children}
    </section>
  );
}
