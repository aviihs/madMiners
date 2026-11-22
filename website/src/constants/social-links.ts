import { Facebook, Github, Globe, Instagram, type LucideIcon } from "lucide-react";

import { site } from "@/lib/content";

export type SocialLink = {
  label: string;
  href: string;
  icon: LucideIcon;
};

/** Social profiles from `site.json`; empty ones are left out. */
export const SOCIAL_LINKS: SocialLink[] = [
  { label: "GitHub", href: site.social.github, icon: Github },
  { label: "Instagram", href: site.social.instagram, icon: Instagram },
  { label: "Facebook", href: site.social.facebook, icon: Facebook },
  { label: "Website", href: site.social.website, icon: Globe },
].filter((link) => link.href.trim() !== "");
