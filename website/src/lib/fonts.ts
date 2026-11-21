import localFont from "next/font/local";

/** The game's own fonts (bundled, OFL licensed), so the site looks like the app. */
export const displayFont = localFont({
  src: "../assets/fonts/LilitaOne-Regular.ttf",
  variable: "--font-display",
  display: "swap",
});

export const bodyFont = localFont({
  src: [
    { path: "../assets/fonts/Nunito-SemiBold.ttf", weight: "600" },
    { path: "../assets/fonts/Nunito-Bold.ttf", weight: "700" },
    { path: "../assets/fonts/Nunito-ExtraBold.ttf", weight: "800" },
    { path: "../assets/fonts/Nunito-Black.ttf", weight: "900" },
  ],
  variable: "--font-body",
  display: "swap",
});
