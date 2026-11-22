import { Facebook, Github, Globe, Instagram, type LucideIcon } from "lucide-react";

import { site } from "@/lib/content";

export type SocialLink = { label: string; href: string; icon: LucideIcon };

/** Shared by the footer and the mobile menu. Empty links in site.json are hidden. */
export const SOCIAL_LINKS: SocialLink[] = [
  { label: "Instagram", href: site.social.instagram, icon: Instagram },
  { label: "Facebook", href: site.social.facebook, icon: Facebook },
  { label: "GitHub", href: site.social.github, icon: Github },
  { label: "Website", href: site.social.website, icon: Globe },
].filter((link) => link.href.trim() !== "");
