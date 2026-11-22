import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

type SectionProps = {
  children: ReactNode;
  id?: string;
  className?: string;
  /** Inner width: "wide" for marketing sections, "text" for reading pages. */
  width?: "wide" | "text";
};

/** Vertical rhythm + horizontal container shared by every section. */
export function Section({ children, id, className, width = "wide" }: SectionProps) {
  return (
    <section
      id={id}
      className={cn(
        "mx-auto w-full scroll-mt-20 px-5 py-14 sm:px-8 md:py-20",
        width === "wide" ? "max-w-6xl" : "max-w-3xl",
        className,
      )}
    >
      {children}
    </section>
  );
}
