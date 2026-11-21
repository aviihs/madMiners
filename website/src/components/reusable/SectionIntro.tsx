import { cn } from "@/lib/utils";

type SectionIntroProps = {
  title: string;
  subtitle?: string;
  className?: string;
};

export function SectionIntro({ title, subtitle, className }: SectionIntroProps) {
  return (
    <div className={cn("mx-auto mb-12 max-w-2xl text-center", className)}>
      <h2 className="text-3xl text-text sm:text-5xl">{title}</h2>
      {subtitle && <p className="mt-4 text-lg text-muted">{subtitle}</p>}
    </div>
  );
}
