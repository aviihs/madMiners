export type NavLink = {
  href: string;
  label: string;
};

/** Main navigation, shared by the header, mobile menu and footer. */
export const NAV_LINKS: NavLink[] = [
  { href: "/", label: "Home" },
  { href: "/about", label: "About" },
  { href: "/contact", label: "Contact" },
  { href: "/privacy-policy", label: "Privacy" },
];

export const LEGAL_LINKS: NavLink[] = [
  { href: "/privacy-policy", label: "Privacy Policy" },
  { href: "/delete-account", label: "Delete account" },
];
