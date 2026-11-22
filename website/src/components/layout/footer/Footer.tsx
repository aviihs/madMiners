import Link from "next/link";

import { BrandLogo } from "@/components/reusable/BrandLogo";
import { LEGAL_LINKS, NAV_LINKS, type NavLink } from "@/constants/navigation";
import { SOCIAL_LINKS } from "@/constants/social-links";
import { site } from "@/lib/content";

export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-line bg-paper-deep/60 border-t">
      <div className="mx-auto grid max-w-6xl gap-10 px-5 py-12 sm:px-8 md:grid-cols-[1.6fr_1fr_1fr]">
        <div className="max-w-xs">
          <BrandLogo />
          <p className="text-ink-soft mt-4 text-[0.9375rem]">{site.tagline}</p>
        </div>
        <FooterColumn title="Game" links={NAV_LINKS} />
        <FooterColumn
          title="Legal & support"
          links={[...LEGAL_LINKS, { href: `mailto:${site.contactEmail}`, label: site.contactEmail }]}
        />
      </div>
      <div className="border-line mx-auto flex max-w-6xl flex-col gap-4 border-t px-5 py-6 sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <p className="text-ink-muted text-[0.8125rem]">
          © {year} {site.developer}, {site.location}
        </p>
        {SOCIAL_LINKS.length > 0 && (
          <ul className="-ml-2 flex items-center gap-1 sm:ml-0" aria-label="Social links">
            {SOCIAL_LINKS.map((link) => (
              <li key={link.label}>
                <a
                  href={link.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={link.label}
                  title={link.label}
                  className="text-ink-muted hover:bg-paper-deep hover:text-ink flex size-9 items-center justify-center rounded-lg transition-colors"
                >
                  <link.icon aria-hidden className="size-4.5" strokeWidth={1.8} />
                </a>
              </li>
            ))}
          </ul>
        )}
      </div>
    </footer>
  );
}

function FooterColumn({ title, links }: { title: string; links: NavLink[] }) {
  return (
    <div>
      <h2 className="text-ink-muted font-sans text-[0.8125rem] font-semibold tracking-wide">{title}</h2>
      <ul className="mt-4 space-y-2.5 text-[0.9375rem]">
        {links.map((link) => (
          <li key={link.href}>
            <Link href={link.href} className="text-ink-soft hover:text-ink break-all transition-colors">
              {link.label}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
