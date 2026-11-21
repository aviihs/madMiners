import type { HomeContent } from "@/types/Home";

export function StatsStrip({ stats }: { stats: HomeContent["stats"] }) {
  return (
    <div className="border-y border-hairline bg-surface/50">
      <dl className="mx-auto grid max-w-6xl grid-cols-2 gap-6 px-5 py-8 sm:grid-cols-4 sm:px-8">
        {stats.map((stat) => (
          <div key={stat.label} className="text-center">
            <dt className="sr-only">{stat.label}</dt>
            <dd className="font-display text-4xl text-gold">{stat.value}</dd>
            <dd className="mt-1 text-sm text-muted">{stat.label}</dd>
          </div>
        ))}
      </dl>
    </div>
  );
}
