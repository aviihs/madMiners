import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

type SectionHeaderProps = {
  /** Small label above the title, e.g. "01 — Features". */
  label?: string;
  title: string;
  description?: string;
  /** Optional element on the right (a link or button). */
  action?: ReactNode;
  className?: string;
  tone?: "light" | "dark";
};

/** Left-aligned section heading with an optional label and action. */
export function SectionHeader({
  label,
  title,
  description,
  action,
  className,
  tone = "light",
}: SectionHeaderProps) {
  const isDark = tone === "dark";
  return (
    <div
      className={cn(
        "mb-10 flex flex-col gap-4 md:mb-12 md:flex-row md:items-end md:justify-between",
        className,
      )}
    >
      <div className="max-w-2xl">
        {label && (
          <p
            className={cn(
              "mb-3 text-[0.8125rem] font-semibold tracking-wide",
              isDark ? "text-night-muted" : "text-accent-ink",
            )}
          >
            {label}
          </p>
        )}
        <h2 className={cn("text-[1.75rem] sm:text-[2.25rem]", isDark ? "text-night-text" : "text-ink")}>
          {title}
        </h2>
        {description && (
          <p className={cn("mt-3 text-[1.0625rem]", isDark ? "text-night-muted" : "text-ink-soft")}>
            {description}
          </p>
        )}
      </div>
      {action}
    </div>
  );
}
