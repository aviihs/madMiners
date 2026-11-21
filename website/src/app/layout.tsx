import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import { Footer } from "@/components/layout/footer/Footer";
import { Navbar } from "@/components/layout/header/Navbar";
import { site } from "@/lib/content";
import { bodyFont, displayFont } from "@/lib/fonts";
import { SITE_URL } from "@/lib/seo";

import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: { default: `${site.storeTitle}`, template: `%s · ${site.name}` },
  description: site.description,
  keywords: site.keywords,
  applicationName: site.name,
  authors: [{ name: site.developer }],
  creator: site.developer,
  openGraph: {
    type: "website",
    siteName: site.name,
    title: site.storeTitle,
    description: site.description,
    url: "/",
  },
  twitter: { card: "summary_large_image", title: site.storeTitle, description: site.description },
  other: { "google-play-app": `app-id=${site.packageName}` },
};

export const viewport: Viewport = {
  themeColor: "#0c0a14",
  colorScheme: "dark",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en" className={`${displayFont.variable} ${bodyFont.variable}`}>
      <body className="flex min-h-dvh flex-col">
        <a
          href="#main"
          className="bg-gold text-on-gold sr-only z-[70] rounded-xl px-4 py-2 focus:not-sr-only focus:fixed focus:top-3 focus:left-3"
        >
          Skip to content
        </a>
        <Navbar />
        <main id="main" className="flex-1">
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}
