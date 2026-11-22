import { fillPlaceholders } from "@/lib/content";
import type { PolicySectionContent } from "@/types/PrivacyPolicy";

/** One numbered section of the policy, rendered from JSON blocks. */
export function PolicySection({ section, number }: { section: PolicySectionContent; number: number }) {
  return (
    <section
      id={section.id}
      className="border-line scroll-mt-24 border-t pt-8 pb-2 first:border-t-0 first:pt-0"
    >
      <h2 className="text-[1.5rem]">
        <span className="text-ink-muted mr-2 tabular-nums">{number}.</span>
        {section.title}
      </h2>
      <div className="text-ink-soft mt-4 space-y-4">
        {section.blocks.map((block, index) => {
          switch (block.type) {
            case "heading":
              return (
                <h3 key={index} className="text-ink pt-2 font-sans text-[1rem] font-semibold tracking-normal">
                  {block.text}
                </h3>
              );
            case "list":
              return (
                <ul key={index} className="marker:text-line-strong list-disc space-y-2 pl-5">
                  {block.items.map((item) => (
                    <li key={item} className="pl-1">
                      {fillPlaceholders(item)}
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
