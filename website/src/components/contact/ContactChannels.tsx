import { ArrowUpRight } from "lucide-react";
import Link from "next/link";

import { ICONS } from "@/lib/icons";
import { site } from "@/lib/content";
import type { ContactChannel } from "@/types/Contact";

const CHANNEL_LINKS: Record<ContactChannel["kind"], { href: string; label: string }> = {
  email: { href: `mailto:${site.contactEmail}`, label: site.contactEmail },
  deletion: { href: "/delete-account", label: "How to delete your account" },
  privacy: { href: "/privacy-policy", label: "Read the privacy policy" },
};

/** Other ways to reach us, as a plain list. */
export function ContactChannels({ channels }: { channels: ContactChannel[] }) {
  return (
    <ul className="divide-line border-line divide-y border-y">
      {channels.map((channel) => {
        const link = CHANNEL_LINKS[channel.kind];
        const Icon = ICONS[channel.icon];
        return (
          <li key={channel.title} className="py-6">
            <h2 className="flex items-center gap-2.5 text-[1.125rem]">
              <Icon aria-hidden className="text-accent size-[1.125rem]" strokeWidth={2} />
              {channel.title}
            </h2>
            <p className="text-ink-soft mt-1.5 text-[0.9375rem]">{channel.text}</p>
            <Link
              href={link.href}
              className="text-ink decoration-line-strong hover:decoration-ink mt-2 inline-flex items-center gap-1 text-[0.9375rem] font-semibold break-all underline underline-offset-4"
            >
              {link.label}
              <ArrowUpRight aria-hidden className="size-4 shrink-0" />
            </Link>
          </li>
        );
      })}
    </ul>
  );
}
