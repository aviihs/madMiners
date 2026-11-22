import { ScreenshotFrame } from "@/components/reusable/ScreenshotFrame";
import { SectionHeader } from "@/components/reusable/SectionHeader";
import type { Screenshot } from "@/types/Home";

type ScreenshotShowcaseProps = {
  title: string;
  description: string;
  items: Screenshot[];
};

/** The one dark band on the site: real screenshots, captioned. */
export function ScreenshotShowcase({ title, description, items }: ScreenshotShowcaseProps) {
  return (
    <section id="screenshots" className="bg-night scroll-mt-16">
      <div className="mx-auto max-w-6xl px-5 py-16 sm:px-8 md:py-20">
        <SectionHeader label="Screenshots" title={title} description={description} tone="dark" />
        <div className="grid gap-x-6 gap-y-8 md:grid-cols-2">
          {items.map((screenshot, index) => (
            <figure
              key={screenshot.src}
              className={index === 0 ? "md:col-span-2 lg:mx-auto lg:w-4/5" : undefined}
            >
              <ScreenshotFrame
                src={screenshot.src}
                alt={screenshot.alt}
                sizes={index === 0 ? "(min-width: 1024px) 880px, 92vw" : "(min-width: 768px) 540px, 92vw"}
              />
              <figcaption className="text-night-muted mt-3 text-[0.875rem]">{screenshot.caption}</figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}
