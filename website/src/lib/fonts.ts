import { Bricolage_Grotesque, Instrument_Sans } from "next/font/google";
import localFont from "next/font/local";

/** Headings: a grotesque with a bit of character. */
export const headingFont = Bricolage_Grotesque({
  subsets: ["latin"],
  weight: ["500", "600", "700"],
  variable: "--font-heading",
  display: "swap",
});

/** Body copy and UI: neutral, very readable at small sizes. */
export const bodyFont = Instrument_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-body",
  display: "swap",
});

/** The game's own logo face, used only for the wordmark. */
export const brandFont = localFont({
  src: "../assets/fonts/LilitaOne-Regular.ttf",
  variable: "--font-brand",
  display: "swap",
});
