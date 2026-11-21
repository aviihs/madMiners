import { cn } from "@/lib/utils";

type SectionIntroProps = {
  title: string;
  subtitle?: string;
  className?: string;
};

export function SectionIntro({ title, subtitle, className }: SectionIntroProps) {
  return (
    <div className={cn("mx-auto mb-12 max-w-2xl text-center", className)}>
      <h2 className="text-text text-3xl sm:text-5xl">{title}</h2>
      {subtitle && <p className="text-muted mt-4 text-lg">{subtitle}</p>}
    </div>
  );
}
