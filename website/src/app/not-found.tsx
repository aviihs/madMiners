import Link from "next/link";

export default function NotFound() {
  return (
    <section className="mx-auto flex max-w-xl flex-col items-start px-5 pt-36 pb-28 sm:px-8">
      <p className="text-accent-ink text-[0.8125rem] font-semibold tracking-wide">404</p>
      <h1 className="mt-3 text-[2.25rem]">You dug a little too deep</h1>
      <p className="text-ink-soft mt-3 text-[1.0625rem]">
        This page doesn&apos;t exist, or it has moved. Let&apos;s get you back to the surface.
      </p>
      <Link
        href="/"
        className="bg-ink hover:bg-ink/85 mt-8 rounded-lg px-5 py-2.5 text-[0.9375rem] font-semibold text-white transition-colors"
      >
        Back to home
      </Link>
    </section>
  );
}
