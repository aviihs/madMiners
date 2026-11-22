import Link from "next/link";

import { NAV_LINKS } from "@/constants/navigation";
import { site } from "@/lib/content";
import { cn } from "@/lib/utils";

/** Link list for small screens (opened from the Navbar). */
export function MobileMenu({ pathname }: { pathname: string }) {
  return (
    <div id="mobile-menu" className="border-line bg-paper border-t px-5 pt-2 pb-5 md:hidden">
      <ul>
        {NAV_LINKS.map((link) => (
          <li key={link.href} className="border-line border-b">
            <Link
              href={link.href}
              aria-current={pathname === link.href ? "page" : undefined}
              className={cn(
                "block py-3.5 text-[1.0625rem] font-medium",
                pathname === link.href ? "text-ink" : "text-ink-soft",
              )}
            >
              {link.label}
            </Link>
          </li>
        ))}
      </ul>
      <a
        href={site.playStoreUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="bg-ink mt-5 block rounded-lg px-4 py-3 text-center font-semibold text-white"
      >
        Get the game on Google Play
      </a>
    </div>
  );
}
