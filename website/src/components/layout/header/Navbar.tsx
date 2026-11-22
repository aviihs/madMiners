"use client";

import { Menu, X } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

import { BrandLogo } from "@/components/reusable/BrandLogo";
import { NAV_LINKS } from "@/constants/navigation";
import { site } from "@/lib/content";
import { cn } from "@/lib/utils";

import { MobileMenu } from "./MobileMenu";

/** Top bar: logo, links and the store link; a menu on small screens. */
export function Navbar() {
  const pathname = usePathname();
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [hasScrolled, setHasScrolled] = useState(false);
  const [menuPath, setMenuPath] = useState(pathname);

  // Close the mobile menu after navigating (state reset during render, no effect needed).
  if (menuPath !== pathname) {
    setMenuPath(pathname);
    setIsMenuOpen(false);
  }

  useEffect(() => {
    const handleScroll = () => setHasScrolled(window.scrollY > 8);
    handleScroll();
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <header
      className={cn(
        "bg-paper fixed inset-x-0 top-0 z-50 border-b transition-[border-color]",
        hasScrolled || isMenuOpen ? "border-line" : "border-transparent",
      )}
    >
      <nav
        className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5 sm:px-8"
        aria-label="Main"
      >
        <BrandLogo />
        <div className="hidden items-center gap-8 md:flex">
          <ul className="flex items-center gap-7">
            {NAV_LINKS.map((link) => {
              const isActive = pathname === link.href;
              return (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    aria-current={isActive ? "page" : undefined}
                    className={cn(
                      "text-[0.9375rem] font-medium transition-colors",
                      isActive ? "text-ink" : "text-ink-muted hover:text-ink",
                    )}
                  >
                    {link.label}
                  </Link>
                </li>
              );
            })}
          </ul>
          <a
            href={site.playStoreUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="bg-ink hover:bg-ink/85 rounded-lg px-3.5 py-2 text-[0.875rem] font-semibold text-white transition-colors"
          >
            Get the game
          </a>
        </div>
        <button
          type="button"
          className="text-ink -mr-2 rounded-lg p-2 md:hidden"
          aria-label={isMenuOpen ? "Close menu" : "Open menu"}
          aria-expanded={isMenuOpen}
          aria-controls="mobile-menu"
          onClick={() => setIsMenuOpen((isOpen) => !isOpen)}
        >
          {isMenuOpen ? <X className="size-6" /> : <Menu className="size-6" />}
        </button>
      </nav>
      {isMenuOpen && <MobileMenu pathname={pathname} />}
    </header>
  );
}
