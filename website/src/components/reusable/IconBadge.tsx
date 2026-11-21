import { ICONS, type IconName } from "@/lib/icons";
import { TONE_CLASSES } from "@/lib/tones";
import { cn } from "@/lib/utils";
import type { Tone } from "@/types/Content";

type IconBadgeProps = {
  icon: IconName;
  tone?: Tone;
  className?: string;
};

/** A content icon in a soft, coloured rounded square. */
export function IconBadge({ icon, tone = "gold", className }: IconBadgeProps) {
  const Icon = ICONS[icon];
  return (
    <span
      className={cn(
        "inline-flex size-12 items-center justify-center rounded-2xl ring-1",
        TONE_CLASSES[tone],
        className,
      )}
    >
      <Icon aria-hidden className="size-6" strokeWidth={2.2} />
    </span>
  );
}
