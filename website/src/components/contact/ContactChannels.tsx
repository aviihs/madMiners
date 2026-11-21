import Link from "next/link";

import { IconBadge } from "@/components/reusable/IconBadge";
import { site } from "@/lib/content";
import type { ContactChannel } from "@/types/Contact";

const CHANNEL_LINKS: Record<ContactChannel["kind"], { href: string; label: string }> = {
  email: { href: `mailto:${site.contactEmail}`, label: site.contactEmail },
  deletion: { href: "/delete-account", label: "How to delete your account" },
  privacy: { href: "/privacy-policy", label: "Read the privacy policy" },
};

export function ContactChannels({ channels }: { channels: ContactChannel[] }) {
  return (
    <div className="space-y-4">
      {channels.map((channel) => {
        const link = CHANNEL_LINKS[channel.kind];
        return (
          <article
            key={channel.title}
            className="border-hairline bg-surface/70 flex gap-4 rounded-3xl border p-5"
          >
            <IconBadge icon={channel.icon} tone={channel.kind === "deletion" ? "lava" : "gold"} />
            <div className="min-w-0">
              <h2 className="text-xl">{channel.title}</h2>
              <p className="text-muted mt-1 text-sm">{channel.text}</p>
              <Link
                href={link.href}
                className="text-gold mt-2 inline-block font-extrabold break-all hover:underline"
              >
                {link.label}
              </Link>
            </div>
          </article>
        );
      })}
    </div>
  );
}
