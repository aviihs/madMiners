import { Reveal } from "@/components/motion/Reveal";
import type { AboutContent } from "@/types/About";

export function AboutStory({ story }: { story: AboutContent["story"] }) {
  return (
    <Reveal className="mx-auto max-w-3xl">
      <h2 className="text-3xl sm:text-4xl">{story.title}</h2>
      <div className="text-muted mt-6 space-y-5 text-lg">
        {story.paragraphs.map((paragraph) => (
          <p key={paragraph}>{paragraph}</p>
        ))}
      </div>
    </Reveal>
  );
}
