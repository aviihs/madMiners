import Image from "next/image";
import Link from "next/link";

export default function NotFound() {
  return (
    <section className="mx-auto flex max-w-xl flex-col items-center px-5 pt-40 pb-24 text-center">
      <Image
        src="/art/miners.png"
        alt=""
        width={1200}
        height={720}
        sizes="320px"
        className="w-80 opacity-90"
      />
      <h1 className="mt-6 text-5xl">Dug too deep</h1>
      <p className="text-muted mt-3 text-lg">
        This page isn&apos;t in the mine. Let&apos;s get you back to the surface.
      </p>
      <Link
        href="/"
        className="bg-gold font-display text-on-gold mt-8 rounded-2xl px-6 py-3 text-lg hover:brightness-110"
      >
        Back to the surface
      </Link>
    </section>
  );
}
