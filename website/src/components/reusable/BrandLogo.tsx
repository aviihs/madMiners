import Image from "next/image";
import Link from "next/link";

import mascot from "@/app/icon.png";
import { site } from "@/lib/content";
import { cn } from "@/lib/utils";

/** App icon + wordmark in the game's logo face; links home. */
export function BrandLogo({ tone = "dark" }: { tone?: "dark" | "light" }) {
  return (
    <Link href="/" className="flex items-center gap-2" aria-label={`${site.name} home`}>
      <span className="bg-accent-soft flex size-9 items-center justify-center overflow-hidden rounded-[10px] ring-1 ring-black/5">
        <Image src={mascot} alt="" width={36} height={36} className="size-9 translate-y-0.5" priority />
      </span>
      <span
        className={cn(
          "font-brand text-[1.375rem] tracking-wide",
          tone === "dark" ? "text-ink" : "text-night-text",
        )}
      >
        {site.name}
      </span>
    </Link>
  );
}
