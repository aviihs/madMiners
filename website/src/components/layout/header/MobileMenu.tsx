import Link from "next/link";

import { NAV_LINKS } from "@/constants/navigation";
import { site } from "@/lib/content";
import { cn } from "@/lib/utils";

/** Drop-down link list for small screens (opened from the Navbar). */
export function MobileMenu({ pathname }: { pathname: string }) {
  return (
    <ul id="mobile-menu" className="border-t border-hairline px-5 py-4 md:hidden">
      {NAV_LINKS.map((link) => (
        <li key={link.href}>
          <Link
            href={link.href}
            aria-current={pathname === link.href ? "page" : undefined}
            className={cn(
              "block rounded-xl px-4 py-3 text-lg font-extrabold",
              pathname === link.href ? "bg-white/6 text-gold" : "text-text",
            )}
          >
            {link.label}
          </Link>
        </li>
      ))}
      <li className="mt-2">
        <a
          href={site.playStoreUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="block rounded-xl bg-gold px-4 py-3 text-center font-display text-lg text-on-gold"
        >
          Play free on Google Play
        </a>
      </li>
    </ul>
  );
}
