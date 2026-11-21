import Image from "next/image";

import { Reveal } from "@/components/motion/Reveal";
import type { Screenshot } from "@/types/Home";

/** Real in-game screenshots: one large, two beside it. */
export function ScreenshotShowcase({ items }: { items: Screenshot[] }) {
  const [featured, ...rest] = items;
  return (
    <div className="grid gap-5 lg:grid-cols-[2fr_1fr]">
      <Reveal>
        <Shot screenshot={featured} sizes="(min-width: 1024px) 720px, 100vw" priority />
      </Reveal>
      <div className="grid gap-5">
        {rest.map((screenshot, index) => (
          <Reveal key={screenshot.src} delay={(index + 1) * 90}>
            <Shot screenshot={screenshot} sizes="(min-width: 1024px) 360px, 100vw" />
          </Reveal>
        ))}
      </div>
    </div>
  );
}

function Shot({
  screenshot,
  sizes,
  priority,
}: {
  screenshot: Screenshot;
  sizes: string;
  priority?: boolean;
}) {
  return (
    <figure className="border-hairline bg-surface overflow-hidden rounded-3xl border shadow-2xl shadow-black/40">
      <Image
        src={screenshot.src}
        alt={screenshot.alt}
        width={1920}
        height={1080}
        sizes={sizes}
        priority={priority}
        className="aspect-video w-full object-cover"
      />
      <figcaption className="text-muted px-5 py-3 text-sm">{screenshot.caption}</figcaption>
    </figure>
  );
}
