import type { AboutContent } from "@/types/About";

/** Heading on the left, story on the right, like a magazine spread. */
export function AboutStory({ story }: { story: AboutContent["story"] }) {
  return (
    <div className="grid gap-6 md:grid-cols-[0.7fr_1.3fr] md:gap-16">
      <h2 className="text-[1.75rem] sm:text-[2rem]">{story.title}</h2>
      <div className="text-ink-soft space-y-5 text-[1.0625rem]">
        {story.paragraphs.map((paragraph, index) => (
          <p key={paragraph} className={index === 0 ? "text-ink text-[1.1875rem]" : undefined}>
            {paragraph}
          </p>
        ))}
      </div>
    </div>
  );
}
