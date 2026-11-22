"use client";

import { ChevronRight, Mail, Play, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { createPortal } from "react-dom";

import { BrandLogo } from "@/components/reusable/BrandLogo";
import { isNavLinkActive, NAV_LINKS } from "@/constants/navigation";
import { SOCIAL_LINKS } from "@/constants/social-links";
import { site } from "@/lib/content";
import { cn } from "@/lib/utils";

const subscribeNoop = () => () => {};

/** True only after hydration, so the portal never renders on the server. */
const useIsClient = () =>
  useSyncExternalStore(
    subscribeNoop,
    () => true,
    () => false,
  );

/**
 * Phones: a two-line menu button that opens a drawer from the left.
 * The drawer stays mounted (hidden and `inert` when closed) so it can slide
 * both in and out with plain CSS. Escape, the backdrop and every link close it.
 * It's portalled to <body>: inside the blurred header, `fixed` would be
 * relative to the header (backdrop-filter creates a containing block).
 */
export function MobileMenu({ pathname }: { pathname: string }) {
  const [isOpen, setIsOpen] = useState(false);
  const [openedAt, setOpenedAt] = useState(pathname);
  const closeButton = useRef<HTMLButtonElement>(null);
  const isClient = useIsClient();
  const close = () => setIsOpen(false);

  // Navigating closes the menu (state reset during render, no effect needed).
  if (openedAt !== pathname) {
    setOpenedAt(pathname);
    setIsOpen(false);
  }

  useEffect(() => {
    if (!isOpen) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButton.current?.focus();
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setIsOpen(false);
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [isOpen]);

  return (
    <>
      <button
        type="button"
        aria-label="Open menu"
        aria-expanded={isOpen}
        aria-controls="mobile-menu"
        onClick={() => setIsOpen(true)}
        className="text-ink hover:bg-paper-deep -ml-2 flex size-10 flex-col items-center justify-center gap-[5px] rounded-full transition-colors md:hidden"
      >
        <span className="h-[1.5px] w-[18px] rounded-full bg-current" />
        <span className="h-[1.5px] w-[12px] self-center rounded-full bg-current" />
      </button>

      {isClient &&
        createPortal(
          <div
            className={cn("fixed inset-0 z-[100] md:hidden", !isOpen && "pointer-events-none")}
            inert={!isOpen}
          >
            <div
              aria-hidden
              onClick={close}
              className={cn(
                "bg-night/40 absolute inset-0 backdrop-blur-sm transition-opacity duration-300",
                isOpen ? "opacity-100" : "opacity-0",
              )}
            />

            <aside
              id="mobile-menu"
              role="dialog"
              aria-modal="true"
              aria-label="Main menu"
              className={cn(
                "bg-paper absolute inset-y-0 left-0 flex w-[84%] max-w-sm flex-col shadow-black/30",
                "transition-[translate,visibility,box-shadow] duration-[400ms] ease-[cubic-bezier(0.16,1,0.3,1)] motion-reduce:transition-none",
                isOpen ? "visible translate-x-0 shadow-2xl" : "invisible -translate-x-full shadow-none",
              )}
            >
              <div className="border-line/70 flex h-16 items-center justify-between border-b px-5">
                <BrandLogo />
                <button
                  ref={closeButton}
                  type="button"
                  aria-label="Close menu"
                  onClick={close}
                  className="text-ink-soft hover:bg-paper-deep hover:text-ink flex size-10 items-center justify-center rounded-full transition-colors"
                >
                  <X aria-hidden className="size-5" />
                </button>
              </div>

              <ul className="flex-1 space-y-1 overflow-y-auto px-3 py-6">
                <li className="text-ink-muted px-3 pb-3 text-[11px] font-semibold tracking-[0.18em] uppercase">
                  Navigate
                </li>
                {NAV_LINKS.map((link, index) => {
                  const isActive = isNavLinkActive(link.href, pathname);
                  const Icon = link.icon;
                  return (
                    <li
                      key={link.href}
                      // Links slide in one after another as the drawer opens.
                      style={{ transitionDelay: isOpen ? `${120 + index * 50}ms` : "0ms" }}
                      className={cn(
                        "transition-[opacity,translate] duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] motion-reduce:transition-none",
                        isOpen ? "translate-x-0 opacity-100" : "-translate-x-4 opacity-0",
                      )}
                    >
                      <Link
                        href={link.href}
                        onClick={close}
                        aria-current={isActive ? "page" : undefined}
                        className={cn(
                          "group flex items-center gap-4 rounded-2xl px-3 py-3 text-[1rem] font-medium transition-colors",
                          isActive
                            ? "bg-paper-deep text-ink"
                            : "text-ink-soft hover:bg-paper-deep/60 hover:text-ink",
                        )}
                      >
                        <span
                          className={cn(
                            "flex size-10 items-center justify-center rounded-xl border transition-colors",
                            isActive
                              ? "from-accent to-accent-ink border-transparent bg-linear-to-br text-white"
                              : "border-line bg-card text-accent-ink",
                          )}
                        >
                          <Icon aria-hidden className="size-[18px]" />
                        </span>
                        {link.label}
                        <ChevronRight
                          aria-hidden
                          className="text-ink-muted ml-auto size-4 transition-transform group-hover:translate-x-0.5"
                        />
                      </Link>
                    </li>
                  );
                })}
              </ul>

              <div
                style={{ transitionDelay: isOpen ? "350ms" : "0ms" }}
                className={cn(
                  "border-line/70 space-y-4 border-t p-5 transition-[opacity,translate] duration-500 motion-reduce:transition-none",
                  isOpen ? "translate-y-0 opacity-100" : "translate-y-3 opacity-0",
                )}
              >
                <a
                  href={site.playStoreUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={close}
                  className="bg-ink hover:bg-accent-ink flex items-center justify-center gap-2 rounded-2xl py-3.5 text-[0.9375rem] font-semibold text-white transition-colors"
                >
                  <Play aria-hidden className="size-4 fill-current" strokeWidth={0} />
                  Get it on Google Play
                </a>
                <div className="flex items-center justify-between gap-3">
                  <a
                    href={`mailto:${site.contactEmail}`}
                    className="text-ink-soft hover:text-accent-ink inline-flex min-w-0 items-center gap-2 text-[0.8125rem] transition-colors"
                  >
                    <Mail aria-hidden className="size-4 shrink-0" />
                    <span className="truncate">{site.contactEmail}</span>
                  </a>
                  <ul className="flex shrink-0 items-center gap-1">
                    {SOCIAL_LINKS.map((link) => (
                      <li key={link.label}>
                        <a
                          href={link.href}
                          target="_blank"
                          rel="noopener noreferrer"
                          aria-label={link.label}
                          className="text-ink-muted hover:bg-paper-deep hover:text-ink flex size-8 items-center justify-center rounded-full transition-colors"
                        >
                          <link.icon aria-hidden className="size-4" />
                        </a>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </aside>
          </div>,
          document.body,
        )}
    </>
  );
}
