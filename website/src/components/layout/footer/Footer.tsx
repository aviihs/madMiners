import Link from "next/link";

import { BrandLogo } from "@/components/reusable/BrandLogo";
import { LEGAL_LINKS, NAV_LINKS, type NavLink } from "@/constants/navigation";
import { site } from "@/lib/content";

export function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-hairline bg-bg border-t">
      <div className="mx-auto grid max-w-6xl gap-10 px-5 py-14 sm:grid-cols-[2fr_1fr_1fr] sm:px-8">
        <div>
          <BrandLogo />
          <p className="text-muted mt-4 max-w-sm">{site.tagline}</p>
          <p className="text-faint mt-4 text-sm">
            Made by {site.developer}, {site.location}.
          </p>
        </div>
        <FooterColumn title="Explore" links={NAV_LINKS} />
        <FooterColumn
          title="Legal"
          links={[...LEGAL_LINKS, { href: `mailto:${site.contactEmail}`, label: site.contactEmail }]}
        />
      </div>
      <div className="border-hairline text-faint border-t px-5 py-6 text-center text-sm">
        © {year} {site.developer}. Google Play is a trademark of Google LLC.
      </div>
    </footer>
  );
}

function FooterColumn({ title, links }: { title: string; links: NavLink[] }) {
  return (
    <div>
      <h2 className="font-display text-text text-lg">{title}</h2>
      <ul className="mt-4 space-y-2.5">
        {links.map((link) => (
          <li key={link.href}>
            <Link href={link.href} className="text-muted hover:text-gold break-all transition">
              {link.label}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
