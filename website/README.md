# Mad Miners website

Promo site, privacy policy and account-deletion page for **Mad Miners: Dig & Treasure**
(`com.madminers.game`). Next.js 16 (App Router), React 19, Tailwind CSS 4, TypeScript. Every page is
static, so it can be hosted anywhere.

| Page | Path | Why it exists |
|---|---|---|
| Home | `/` | Game promo: features, real screenshots, FAQ, Google Play button |
| About | `/about` | The story and values (fair play, honesty, privacy) |
| Contact | `/contact` | Email + a form that opens the visitor's email app (no backend) |
| Privacy Policy | `/privacy-policy` | **Required by Google Play** (Store listing → Privacy policy URL) |
| Delete account | `/delete-account` | **Required by Google Play** (Data safety → account deletion URL) |

## Run it

```bash
cd website
bun install
bun dev            # http://localhost:3000
bun run build      # production build
bun start          # serve the build
```

`npm install` / `npm run dev` work too. Checks: `bun run lint`, `bun run typecheck`, `bun run format`.

## Before you publish

1. **Contact email.** `contactEmail` in `src/data/site.json` is used everywhere: privacy policy,
   deletion page, contact form, footer.
2. **Site URL.** Set `NEXT_PUBLIC_SITE_URL` (see `.env.example`) to the real address, so canonical
   links, the sitemap and social cards point to it.
3. **Policy accuracy.** The policy describes what the game does today (see "What the policy is based
   on" below). If you add ads, analytics, purchases or new data, update
   `src/data/privacy-policy.json` and `policyLastUpdated` in `site.json`.
4. **Deletion requests.** The server has no delete-account API yet, so requests arrive by email and
   are handled by hand. Deleting the `users` row removes everything else (all tables use
   `ON DELETE CASCADE`; finished matches keep only the winner's name as text).

## Deploy

Vercel: import the repo, set **Root Directory** to `website`, add `NEXT_PUBLIC_SITE_URL`, deploy.
Any Node host works with `bun run build && bun start`.

## Structure

```
src/
  app/                  routes (page.tsx per page) + sitemap, robots, manifest, OG image, icons
  components/
    layout/             header (Navbar, MobileMenu) and Footer
    home/ about/ contact/ privacy-policy/   page sections
    reusable/           PageHero, Section, SectionIntro, IconCardGrid, FaqList, PlayStoreButton…
    motion/Reveal.tsx   scroll fade-in (IntersectionObserver + CSS, no animation library)
  constants/            navigation links
  data/                 all page copy as JSON (edit text here, not in components)
  hooks/                use-active-section (privacy policy table of contents)
  lib/                  typed content access, SEO helpers, structured data, fonts, icons, mailto
  types/                content types
public/
  screenshots/          real 1920x1080 in-game screenshots (also usable on Google Play)
  art/miners.png        miner characters rendered from the game's own drawing code
```

Rules follow the same spirit as Taskify-Web: content lives in `src/data`, components only render it,
icons come from `lucide-react` through `src/lib/icons.ts` (no inline SVG), descriptive names, and
Server Components by default (client components only for the navbar, scroll reveal, table of
contents, reading progress and contact form).

## What the policy is based on

Checked against the code on 2026-11-21:

- Database (`server/database/migrations`): username, account id, Google subject + email (only if
  linked), hashed session tokens, stats, wallet + transaction history, Locker items, match history,
  daily stats and daily-reward streak.
- Chat is relayed to the match and never stored. IP addresses are used in memory for rate limiting
  only.
- On the device: settings, session and server address (`shared_preferences`).
- Android permissions: internet, network state, Wi-Fi state + Wi-Fi multicast (to find a server on
  the local network), vibrate (haptic feedback). See `app/android/app/src/main/AndroidManifest.xml`.
- No ads, analytics, advertising ID, location, contacts, camera, microphone or real-money purchases.

The policy also says connections are encrypted (HTTPS / WSS): deploy the game server behind HTTPS.
