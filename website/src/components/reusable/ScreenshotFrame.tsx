import Image from "next/image";

import { cn } from "@/lib/utils";

type ScreenshotFrameProps = {
  src: string;
  alt: string;
  sizes: string;
  priority?: boolean;
  className?: string;
};

/** A landscape phone bezel around a real game screenshot. */
export function ScreenshotFrame({ src, alt, sizes, priority, className }: ScreenshotFrameProps) {
  return (
    <div
      className={cn(
        "shadow-raised rounded-[1.375rem] bg-[#0d0c0a] p-[0.55rem] ring-1 ring-black/40",
        className,
      )}
    >
      <Image
        src={src}
        alt={alt}
        width={1920}
        height={1080}
        sizes={sizes}
        priority={priority}
        className="aspect-video w-full rounded-[0.95rem] object-cover"
      />
    </div>
  );
}
