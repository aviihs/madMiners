import Image from "next/image";

import { Reveal } from "@/components/motion/Reveal";

import { PlayStoreButton } from "./PlayStoreButton";

type CallToActionProps = {
  title: string;
  subtitle: string;
  button: string;
};

/** Closing banner with the Google Play button. */
export function CallToAction({ title, subtitle, button }: CallToActionProps) {
  return (
    <section className="mx-auto max-w-6xl px-5 pb-24 sm:px-8">
      <Reveal>
        <div className="relative overflow-hidden rounded-[2rem] border border-gold/25 bg-gradient-to-br from-bg-top via-surface to-bg px-8 py-14 text-center sm:px-16">
          <div className="pointer-events-none absolute -top-24 left-1/2 size-80 -translate-x-1/2 rounded-full bg-gold/20 blur-3xl" />
          <Image
            src="/art/miners.png"
            alt=""
            width={1200}
            height={720}
            sizes="(min-width: 640px) 384px, 288px"
            className="relative mx-auto -mt-4 mb-2 w-72 sm:w-96"
          />
          <h2 className="relative text-4xl sm:text-5xl">{title}</h2>
          <p className="relative mt-3 text-lg text-muted">{subtitle}</p>
          <PlayStoreButton label={button} className="relative mt-8" />
        </div>
      </Reveal>
    </section>
  );
}
