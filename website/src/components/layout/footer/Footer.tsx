import { ArrowRight, MessageCircle } from "lucide-react";
import Link from "next/link";

import { BrandLogo } from "@/components/reusable/BrandLogo";
import { FOOTER_LINK_GROUPS } from "@/constants/navigation";
import { SOCIAL_LINKS } from "@/constants/social-links";
import { site } from "@/lib/content";

/**
 * Brand column (tagline, "Talk to us", socials) + link columns, a bottom bar,
 * and the game's name set huge and faded along the bottom edge.
 * Phones: brand on top, link columns two by two.
 */
export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-line/70 bg-paper relative overflow-hidden border-t">
      <div
        aria-hidden
        className="via-accent/50 absolute inset-x-0 top-0 h-px bg-linear-to-r from-transparent to-transparent"
      />

      <div className="mx-auto grid max-w-6xl grid-cols-2 gap-x-6 gap-y-10 px-5 pt-14 pb-10 sm:grid-cols-3 sm:px-6 sm:pt-16 lg:grid-cols-[1.6fr_1fr_1fr_1fr] lg:gap-10">
        <div className="col-span-2 sm:col-span-3 lg:col-span-1 lg:max-w-xs">
          <BrandLogo />
          <p className="text-ink-soft mt-4 max-w-sm text-[0.875rem] leading-relaxed">{site.tagline}</p>

          <div className="mt-6 flex flex-wrap items-center gap-3">
            <Link
              href="/contact"
              className="group border-line text-ink hover:border-accent inline-flex items-center gap-2 rounded-full border px-4 py-2 text-[0.875rem] font-medium transition-colors"
            >
              <MessageCircle aria-hidden className="text-accent-ink size-4" />
              Talk to us
              <ArrowRight aria-hidden className="size-4 transition-transform group-hover:translate-x-0.5" />
            </Link>
            {SOCIAL_LINKS.length > 0 && (
              <ul className="flex items-center gap-1.5" aria-label="Social links">
                {SOCIAL_LINKS.map((link) => (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      aria-label={link.label}
                      title={link.label}
                      className="border-line text-ink-soft hover:border-accent hover:text-accent-ink flex size-9 items-center justify-center rounded-full border transition-colors"
                    >
                      <link.icon aria-hidden className="size-4" />
                    </a>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>

        {FOOTER_LINK_GROUPS.map((group) => (
          <div key={group.title}>
            <h2 className="text-ink-muted font-sans text-[0.75rem] font-semibold tracking-[0.16em] uppercase">
              {group.title}
            </h2>
            <ul className="mt-4 space-y-1 sm:mt-5 sm:space-y-3">
              {group.links.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-ink-soft hover:text-ink block py-1.5 text-[0.875rem] transition-colors sm:inline sm:py-0"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="border-line/70 border-t">
        <div className="text-ink-muted mx-auto flex max-w-6xl flex-col items-center gap-2 px-5 py-6 text-center text-[0.875rem] sm:flex-row sm:justify-between sm:px-6 sm:text-left">
          <p>
            © {year} {site.developer}, {site.location}. All rights reserved.
          </p>
          <a
            href={`mailto:${site.contactEmail}`}
            className="text-ink-soft hover:text-accent-ink font-medium break-all transition-colors"
          >
            {site.contactEmail}
          </a>
        </div>
      </div>

      <p
        aria-hidden
        className="font-brand from-line pointer-events-none -mb-3 bg-linear-to-b to-transparent bg-clip-text text-center text-[16vw] leading-none tracking-tight whitespace-nowrap text-transparent select-none sm:-mb-5 lg:-mb-8 lg:text-[11.5rem]"
      >
        {site.name}
      </p>
    </footer>
  );
}
