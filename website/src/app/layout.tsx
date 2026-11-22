import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import { Footer } from "@/components/layout/footer/Footer";
import { Navbar } from "@/components/layout/header/Navbar";
import { JsonLd } from "@/components/reusable/JsonLd";
import { site } from "@/lib/content";
import { bodyFont, brandFont, headingFont } from "@/lib/fonts";
import { SITE_URL } from "@/lib/seo";
import { organizationStructuredData, websiteStructuredData } from "@/lib/structured-data";

import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: { default: site.seoTitle, template: `%s · ${site.name}` },
  description: site.seoDescription,
  keywords: site.keywords,
  applicationName: site.name,
  category: "games",
  authors: [{ name: site.developer, url: site.social.website || undefined }],
  creator: site.developer,
  publisher: site.developer,
  alternates: { canonical: "/" },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
  openGraph: {
    type: "website",
    siteName: site.name,
    title: site.seoTitle,
    description: site.seoDescription,
    url: "/",
    locale: "en_US",
  },
  twitter: { card: "summary_large_image", title: site.seoTitle, description: site.seoDescription },
  // Search Console / Bing ownership checks: paste the codes into env vars.
  verification: {
    google: process.env.NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION,
    other: process.env.NEXT_PUBLIC_BING_SITE_VERIFICATION
      ? { "msvalidate.01": process.env.NEXT_PUBLIC_BING_SITE_VERIFICATION }
      : undefined,
  },
  // Links this site to the Android app (Google uses it to connect the two).
  appLinks: { android: { package: site.packageName, app_name: site.name } },
  other: { "google-play-app": `app-id=${site.packageName}` },
};

export const viewport: Viewport = {
  themeColor: "#f7f5f0",
  colorScheme: "light",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en" className={`${headingFont.variable} ${bodyFont.variable} ${brandFont.variable}`}>
      <body className="flex min-h-dvh flex-col">
        <JsonLd data={organizationStructuredData()} />
        <JsonLd data={websiteStructuredData()} />
        <a
          href="#main"
          className="bg-ink sr-only z-[70] rounded-lg px-4 py-2 text-white focus:not-sr-only focus:fixed focus:top-3 focus:left-3"
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
