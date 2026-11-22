import type { HomeContent } from "@/types/Home";

/** Four key numbers separated by hairlines (1px grid gap over the line colour). */
export function FactsRow({ facts }: { facts: HomeContent["stats"] }) {
  return (
    <div className="mx-auto max-w-6xl px-5 sm:px-8">
      <dl className="border-line bg-line grid grid-cols-2 gap-px overflow-hidden rounded-2xl border md:grid-cols-4">
        {facts.map((fact) => (
          <div key={fact.label} className="bg-paper flex flex-col-reverse gap-1 px-5 py-5 sm:px-6">
            <dt className="text-ink-muted text-[0.875rem]">{fact.label}</dt>
            <dd className="font-heading text-ink text-[2rem] leading-none font-semibold tracking-tight">
              {fact.value}
            </dd>
          </div>
        ))}
      </dl>
    </div>
  );
}
