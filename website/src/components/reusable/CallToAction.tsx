import Link from "next/link";

import { PlayStoreButton } from "./PlayStoreButton";

type CallToActionProps = {
  title: string;
  subtitle: string;
};

/** Closing band: one line of copy and the store badge. */
export function CallToAction({ title, subtitle }: CallToActionProps) {
  return (
    <section className="mx-auto w-full max-w-6xl px-5 pb-16 sm:px-8 md:pb-24">
      <div className="border-line bg-card shadow-card flex flex-col gap-6 rounded-2xl border p-7 sm:p-10 md:flex-row md:items-center md:justify-between">
        <div>
          <h2 className="text-[1.75rem]">{title}</h2>
          <p className="text-ink-soft mt-2">
            {subtitle} Questions first?{" "}
            <Link
              href="/contact"
              className="text-ink decoration-line-strong hover:decoration-ink font-medium underline underline-offset-4"
            >
              Get in touch
            </Link>
            .
          </p>
        </div>
        <PlayStoreButton className="shrink-0 self-start md:self-auto" />
      </div>
    </section>
  );
}
