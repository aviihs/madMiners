import Image from "next/image";
import Link from "next/link";

import mascot from "@/app/icon.png";
import { site } from "@/lib/content";

/** Mascot + wordmark, links home. */
export function BrandLogo() {
  return (
    <Link href="/" className="flex items-center gap-2.5" aria-label={`${site.name} home`}>
      <Image src={mascot} alt="" width={40} height={40} className="size-10" priority />
      <span className="font-display text-gold text-2xl tracking-wide">{site.name}</span>
    </Link>
  );
}
