import { Reveal } from "@/components/motion/Reveal";
import type { Step } from "@/types/Content";

/** Numbered "how a match works" timeline. */
export function StepsSection({ items }: { items: Step[] }) {
  return (
    <ol className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
      {items.map((step, index) => (
        <Reveal key={step.title} delay={index * 80}>
          <li className="relative h-full rounded-3xl border border-hairline bg-surface/60 p-6">
            <span className="flex size-11 items-center justify-center rounded-full bg-gold font-display text-xl text-on-gold">
              {index + 1}
            </span>
            <h3 className="mt-5 text-2xl">{step.title}</h3>
            <p className="mt-2 text-muted">{step.text}</p>
          </li>
        </Reveal>
      ))}
    </ol>
  );
}
