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

/** Sticky top bar: logo, links, Play button, and a menu on small screens. */
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
    const handleScroll = () => setHasScrolled(window.scrollY > 12);
    handleScroll();
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 transition-colors",
        hasScrolled || isMenuOpen ? "border-hairline bg-bg/85 border-b backdrop-blur-md" : "bg-transparent",
      )}
    >
      <nav
        className="mx-auto flex h-18 max-w-6xl items-center justify-between px-5 sm:px-8"
        aria-label="Main"
      >
        <BrandLogo />
        <ul className="hidden items-center gap-1 md:flex">
          {NAV_LINKS.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
                aria-current={pathname === link.href ? "page" : undefined}
                className={cn(
                  "text-muted hover:text-text rounded-xl px-4 py-2 font-extrabold transition",
                  pathname === link.href && "text-text bg-white/6",
                )}
              >
                {link.label}
              </Link>
            </li>
          ))}
          <li className="ml-2">
            <a
              href={site.playStoreUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="bg-gold font-display text-on-gold rounded-xl px-4 py-2 transition hover:brightness-110"
            >
              Play free
            </a>
          </li>
        </ul>
        <button
          type="button"
          className="text-text rounded-xl p-2 md:hidden"
          aria-label={isMenuOpen ? "Close menu" : "Open menu"}
          aria-expanded={isMenuOpen}
          aria-controls="mobile-menu"
          onClick={() => setIsMenuOpen((isOpen) => !isOpen)}
        >
          {isMenuOpen ? <X className="size-7" /> : <Menu className="size-7" />}
        </button>
      </nav>
      {isMenuOpen && <MobileMenu pathname={pathname} />}
    </header>
  );
}
