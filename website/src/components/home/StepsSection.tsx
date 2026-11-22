import type { Step } from "@/types/Content";

/** "How a match works" as a simple ruled timeline. */
export function StepsSection({ items }: { items: Step[] }) {
  return (
    <ol className="grid gap-y-8 sm:grid-cols-2 sm:gap-x-8 lg:grid-cols-4">
      {items.map((step, index) => (
        <li key={step.title} className="border-ink border-t-2 pt-5">
          <p className="text-ink-muted text-[0.8125rem] font-semibold tabular-nums">Step {index + 1}</p>
          <h3 className="mt-2 text-[1.25rem]">{step.title}</h3>
          <p className="text-ink-soft mt-2 text-[0.9375rem]">{step.text}</p>
        </li>
      ))}
    </ol>
  );
}
