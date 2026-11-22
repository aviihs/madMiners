"use client";

import { ArrowRight } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

import { BrandLogo } from "@/components/reusable/BrandLogo";
import { isNavLinkActive, NAV_LINKS } from "@/constants/navigation";
import { site } from "@/lib/content";
import { cn } from "@/lib/utils";

import { MobileMenu } from "./MobileMenu";

/**
 * Fixed header: menu button + logo on the left, pill links in the middle
 * (desktop), "Get the game" on the right. Turns frosted once you scroll.
 */
export function Navbar() {
  const pathname = usePathname();
  const [hasScrolled, setHasScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => setHasScrolled(window.scrollY > 8);
    handleScroll();
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 border-b transition-[background-color,border-color,box-shadow] duration-300",
        hasScrolled
          ? "bg-paper/80 border-line/70 shadow-[0_8px_30px_-12px_rgb(28_26_22/0.18)] backdrop-blur-xl backdrop-saturate-150"
          : "bg-paper/90 border-transparent backdrop-blur-md",
      )}
    >
      <nav
        className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6"
        aria-label="Main"
      >
        <div className="flex items-center gap-1.5">
          <MobileMenu pathname={pathname} />
          <BrandLogo />
        </div>

        <ul className="hidden items-center md:flex">
          {NAV_LINKS.map((link) => {
            const isActive = isNavLinkActive(link.href, pathname);
            return (
              <li key={link.href} className="relative">
                <Link
                  href={link.href}
                  aria-current={isActive ? "page" : undefined}
                  className={cn(
                    "hover:bg-paper-deep block rounded-full px-3.5 py-2 text-[0.875rem] font-medium transition-colors",
                    isActive ? "text-ink" : "text-ink-soft hover:text-ink",
                  )}
                >
                  {link.label}
                </Link>
                {isActive && (
                  <span
                    aria-hidden
                    className="bg-accent absolute -bottom-[13px] left-1/2 h-0.5 w-5 -translate-x-1/2 rounded-full"
                  />
                )}
              </li>
            );
          })}
        </ul>

        <a
          href={site.playStoreUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="group bg-ink hover:bg-accent-ink inline-flex items-center gap-1.5 rounded-full py-2 pr-3 pl-4 text-[0.875rem] font-semibold text-white shadow-sm transition-colors"
        >
          <span>
            Get<span className="hidden sm:inline"> the game</span>
          </span>
          <ArrowRight aria-hidden className="size-4 transition-transform group-hover:translate-x-0.5" />
        </a>
      </nav>
    </header>
  );
}
