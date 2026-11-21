import { ImageResponse } from "next/og";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

import { site } from "@/lib/content";

export const alt = `${site.storeTitle}: ${site.tagline}`;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** Social share card, generated at build time from the game's own art. */
export default async function OpengraphImage() {
  const [miners, font] = await Promise.all([
    readFile(join(process.cwd(), "public/art/miners.png")),
    readFile(join(process.cwd(), "src/assets/fonts/LilitaOne-Regular.ttf")),
  ]);
  const minersSrc = `data:image/png;base64,${miners.toString("base64")}`;

  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        background: "radial-gradient(circle at 50% 0%, #3b2580 0%, #120e1f 55%, #0c0a14 100%)",
        fontFamily: "Lilita",
      }}
    >
      <img src={minersSrc} width={600} height={360} alt="" />
      <div style={{ fontSize: 96, color: "#ffc233", marginTop: -10 }}>{site.name}</div>
      <div style={{ fontSize: 40, color: "#f6f2ff" }}>{site.tagline}</div>
    </div>,
    { ...size, fonts: [{ name: "Lilita", data: font, style: "normal", weight: 400 }] },
  );
}
