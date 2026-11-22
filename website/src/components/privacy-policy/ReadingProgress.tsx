"use client";

import { useEffect, useState } from "react";

/** Thin bar under the header showing how far you've read. */
export function ReadingProgress() {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      const scrollable = document.documentElement.scrollHeight - window.innerHeight;
      setProgress(scrollable > 0 ? Math.min(1, window.scrollY / scrollable) : 0);
    };
    handleScroll();
    window.addEventListener("scroll", handleScroll, { passive: true });
    window.addEventListener("resize", handleScroll);
    return () => {
      window.removeEventListener("scroll", handleScroll);
      window.removeEventListener("resize", handleScroll);
    };
  }, []);

  return (
    <div aria-hidden className="fixed inset-x-0 top-16 z-40 h-0.5">
      <div className="bg-accent h-full origin-left" style={{ transform: `scaleX(${progress})` }} />
    </div>
  );
}
