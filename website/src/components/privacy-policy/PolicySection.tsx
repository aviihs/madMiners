import { fillPlaceholders } from "@/lib/content";
import type { PolicySectionContent } from "@/types/PrivacyPolicy";

/** One numbered section of the policy, rendered from JSON blocks. */
export function PolicySection({ section, number }: { section: PolicySectionContent; number: number }) {
  return (
    <section id={section.id} className="border-hairline scroll-mt-28 border-b py-10 first:pt-0 last:border-0">
      <h2 className="text-3xl">
        <span className="text-gold mr-3">{number}.</span>
        {section.title}
      </h2>
      <div className="text-muted mt-5 space-y-4">
        {section.blocks.map((block, index) => {
          switch (block.type) {
            case "heading":
              return (
                <h3 key={index} className="font-body text-text pt-2 text-lg font-black">
                  {block.text}
                </h3>
              );
            case "list":
              return (
                <ul key={index} className="space-y-2.5 pl-1">
                  {block.items.map((item) => (
                    <li key={item} className="flex gap-3">
                      <span aria-hidden className="bg-gold mt-2.5 size-1.5 shrink-0 rounded-full" />
                      <span>{fillPlaceholders(item)}</span>
                    </li>
                  ))}
                </ul>
              );
            default:
              return <p key={index}>{fillPlaceholders(block.text)}</p>;
          }
        })}
      </div>
    </section>
  );
}
