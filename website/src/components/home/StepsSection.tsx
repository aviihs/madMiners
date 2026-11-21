import { Reveal } from "@/components/motion/Reveal";
import type { Step } from "@/types/Content";

/** Numbered "how a match works" timeline. */
export function StepsSection({ items }: { items: Step[] }) {
  return (
    <ol className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
      {items.map((step, index) => (
        <Reveal key={step.title} delay={index * 80}>
          <li className="border-hairline bg-surface/60 relative h-full rounded-3xl border p-6">
            <span className="bg-gold font-display text-on-gold flex size-11 items-center justify-center rounded-full text-xl">
              {index + 1}
            </span>
            <h3 className="mt-5 text-2xl">{step.title}</h3>
            <p className="text-muted mt-2">{step.text}</p>
          </li>
        </Reveal>
      ))}
    </ol>
  );
}
