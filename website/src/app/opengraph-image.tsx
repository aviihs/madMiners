import { ImageResponse } from "next/og";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

import { site } from "@/lib/content";

export const alt = `${site.storeTitle}: ${site.tagline}`;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** Social share card: wordmark and tagline beside a real screenshot. */
export default async function OpengraphImage() {
  const [screenshot, font] = await Promise.all([
    readFile(join(process.cwd(), "public/screenshots/deep-mine.jpg")),
    readFile(join(process.cwd(), "src/assets/fonts/LilitaOne-Regular.ttf")),
  ]);
  const screenshotSrc = `data:image/jpeg;base64,${screenshot.toString("base64")}`;

  return new ImageResponse(
    <div
      style={{ width: "100%", height: "100%", display: "flex", background: "#f7f5f0", padding: 64, gap: 48 }}
    >
      <div style={{ display: "flex", flexDirection: "column", justifyContent: "center", width: 440 }}>
        <div style={{ fontFamily: "Lilita", fontSize: 84, color: "#1c1a16", lineHeight: 1 }}>{site.name}</div>
        <div style={{ marginTop: 24, fontSize: 34, color: "#4a463e", lineHeight: 1.3 }}>{site.tagline}</div>
        <div style={{ marginTop: 36, fontSize: 24, color: "#8f5a07" }}>Free on Google Play</div>
      </div>
      <div style={{ display: "flex", alignItems: "center", flex: 1 }}>
        <div style={{ display: "flex", background: "#0d0c0a", padding: 10, borderRadius: 26 }}>
          <img src={screenshotSrc} width={560} height={315} style={{ borderRadius: 18 }} alt="" />
        </div>
      </div>
    </div>,
    { ...size, fonts: [{ name: "Lilita", data: font, style: "normal", weight: 400 }] },
  );
}
