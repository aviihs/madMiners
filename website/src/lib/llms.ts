import { aboutContent, homeContent, privacyPolicyContent, site } from "@/lib/content";
import { absoluteUrl } from "@/lib/seo";

/**
 * llms.txt (https://llmstxt.org): a plain Markdown summary of the site for AI
 * assistants and answer engines, built from the same JSON as the pages, so it
 * never drifts from what the site says.
 */

const pages = [
  { name: "Home", path: "/", about: "What the game is, features, screenshots and FAQ" },
  { name: "About", path: "/about", about: "Who makes Mad Miners and why" },
  { name: "Privacy Policy", path: "/privacy-policy", about: "What the game collects and how to delete it" },
  { name: "Delete your account", path: "/delete-account", about: "How to request account and data deletion" },
  { name: "Contact", path: "/contact", about: "Support, bug reports and feedback" },
];

function header() {
  const { hero, stats } = homeContent;
  return [
    `# ${site.storeTitle}`,
    "",
    `> ${site.description}`,
    "",
    `${site.name} is a free 2D multiplayer mining and treasure-hunt game for Android by ${site.developer} (${site.location}). ${hero.subtitle}`,
    "",
    "## Key facts",
    "",
    `- Platform: Android (Google Play, package \`${site.packageName}\`)`,
    `- Get it: ${site.playStoreUrl}`,
    "- Price: free. No ads, no pay-to-win, cosmetics are earned by playing.",
    "- Modes: online real-time multiplayer, and offline practice against bots.",
    ...stats.map((s) => `- ${s.value} ${s.label}`),
    `- Contact: ${site.contactEmail}`,
  ];
}

function pageLinks() {
  return ["## Pages", "", ...pages.map((p) => `- [${p.name}](${absoluteUrl(p.path)}): ${p.about}`)];
}

function faq() {
  return [
    "## FAQ",
    "",
    ...homeContent.faq.items.flatMap((item) => [`### ${item.question}`, "", item.answer, ""]),
  ];
}

/** Short version: what it is, key facts, links. */
export function llmsTxt() {
  return [
    ...header(),
    "",
    ...pageLinks(),
    "",
    ...faq(),
    "## Optional",
    "",
    `- [Full details](${absoluteUrl("/llms-full.txt")}): features, how to play, fair play and privacy summary`,
    "",
  ].join("\n");
}

/** Long version: everything a model needs to answer questions about the game. */
export function llmsFullTxt() {
  const { features, steps, fairPlay } = homeContent;
  return [
    ...header(),
    "",
    `## ${features.title}`,
    "",
    features.subtitle,
    "",
    ...features.items.map((f) => `- **${f.title}**: ${f.text}`),
    "",
    `## ${steps.title}`,
    "",
    ...steps.items.map((s, i) => `${i + 1}. **${s.title}**: ${s.text}`),
    "",
    `## ${fairPlay.title}`,
    "",
    ...fairPlay.items.map((f) => `- **${f.title}**: ${f.text}`),
    "",
    `## ${aboutContent.story.title}`,
    "",
    ...aboutContent.story.paragraphs.flatMap((p) => [p, ""]),
    "## Privacy at a glance",
    "",
    ...privacyPolicyContent.highlights.map((h) => `- **${h.title}**: ${h.text}`),
    `- Full policy: ${absoluteUrl("/privacy-policy")}`,
    "",
    ...pageLinks(),
    "",
    ...faq(),
  ].join("\n");
}

export const textResponse = (body: string) =>
  new Response(body, {
    headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "public, max-age=3600" },
  });
