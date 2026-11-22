import { House, Mail, ShieldCheck, Sparkles, type LucideIcon } from "lucide-react";

export type NavLink = {
  href: string;
  label: string;
};

export type MainNavLink = NavLink & { icon: LucideIcon };

/** Main navigation, shared by the header and the mobile menu. */
export const NAV_LINKS: MainNavLink[] = [
  { href: "/", label: "Home", icon: House },
  { href: "/about", label: "About", icon: Sparkles },
  { href: "/contact", label: "Contact", icon: Mail },
  { href: "/privacy-policy", label: "Privacy", icon: ShieldCheck },
];

export const LEGAL_LINKS: NavLink[] = [
  { href: "/privacy-policy", label: "Privacy Policy" },
  { href: "/delete-account", label: "Delete account" },
];

/** Footer columns. Hash links point into the home page. */
export const FOOTER_LINK_GROUPS: { title: string; links: NavLink[] }[] = [
  {
    title: "Game",
    links: [
      { href: "/#features", label: "Features" },
      { href: "/#screenshots", label: "Screenshots" },
      { href: "/#how-it-works", label: "How it plays" },
      { href: "/#fair-play", label: "Fair play" },
      { href: "/#faq", label: "FAQ" },
    ],
  },
  {
    title: "Studio",
    links: [
      { href: "/about", label: "About" },
      { href: "/contact", label: "Contact" },
    ],
  },
  { title: "Legal", links: LEGAL_LINKS },
];

/** Hash links ("/#faq") point into a page, so only exact paths count as active. */
export const isNavLinkActive = (href: string, pathname: string) => !href.includes("#") && href === pathname;
