import { ICONS } from "@/lib/icons";
import type { AboutContent } from "@/types/About";

/** Values as a two-by-two grid separated by hairlines. */
export function AboutValues({ values }: { values: AboutContent["values"] }) {
  return (
    <div className="grid gap-6 md:grid-cols-[0.7fr_1.3fr] md:gap-16">
      <h2 className="text-[1.75rem] sm:text-[2rem]">{values.title}</h2>
      <dl className="border-line bg-line grid gap-px overflow-hidden rounded-2xl border sm:grid-cols-2">
        {values.items.map((value) => {
          const Icon = ICONS[value.icon];
          return (
            <div key={value.title} className="bg-card p-6">
              <dt className="font-heading flex items-center gap-2.5 text-[1.125rem] font-semibold">
                <Icon aria-hidden className="text-accent size-[1.125rem]" strokeWidth={2} />
                {value.title}
              </dt>
              <dd className="text-ink-soft mt-2 text-[0.9375rem]">{value.text}</dd>
            </div>
          );
        })}
      </dl>
    </div>
  );
}
