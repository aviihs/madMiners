"use client";

import { type FormEvent, useState } from "react";

import { site } from "@/lib/content";
import { buildMailto } from "@/lib/mailto";
import type { ContactContent } from "@/types/Contact";

const FIELD_CLASSES =
  "mt-1.5 block w-full rounded-lg border border-line-strong bg-card px-3.5 py-2.5 text-[0.9375rem] text-ink shadow-[inset_0_1px_1px_rgb(28_26_22/0.04)] placeholder:text-ink-muted/70 focus:border-ink focus:ring-0 focus:outline-none";
const LABEL_CLASSES = "block text-[0.875rem] font-semibold text-ink";

/**
 * Writes the message into the visitor's own email app (mailto). The site has
 * no backend, so nothing typed here is stored or sent anywhere else.
 */
export function ContactForm({ form }: { form: ContactContent["form"] }) {
  const [topic, setTopic] = useState(form.topics[0]);
  const [username, setUsername] = useState("");
  const [message, setMessage] = useState("");

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const body = [message.trim(), "", username.trim() ? `In-game username: ${username.trim()}` : ""]
      .join("\n")
      .trim();
    window.location.href = buildMailto({ to: site.contactEmail, subject: `[Mad Miners] ${topic}`, body });
  };

  return (
    <form onSubmit={handleSubmit} className="border-line bg-card shadow-card rounded-2xl border p-6 sm:p-8">
      <h2 className="text-[1.375rem]">{form.title}</h2>
      <p className="text-ink-muted mt-1.5 text-[0.875rem]">{form.note}</p>

      <div className="mt-6 grid gap-5 sm:grid-cols-2">
        <label className={LABEL_CLASSES}>
          Topic
          <select value={topic} onChange={(event) => setTopic(event.target.value)} className={FIELD_CLASSES}>
            {form.topics.map((option) => (
              <option key={option}>{option}</option>
            ))}
          </select>
        </label>
        <label className={LABEL_CLASSES}>
          In-game username <span className="text-ink-muted font-normal">(optional)</span>
          <input
            value={username}
            onChange={(event) => setUsername(event.target.value)}
            maxLength={24}
            placeholder="e.g. Sagar_07"
            className={FIELD_CLASSES}
          />
        </label>
      </div>

      <label className={`${LABEL_CLASSES} mt-5`}>
        Message
        <textarea
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          required
          rows={6}
          maxLength={2000}
          placeholder="What happened, or what would you like to see?"
          className={`${FIELD_CLASSES} resize-y`}
        />
      </label>

      <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-ink-muted text-[0.8125rem]">Sends to {site.contactEmail}</p>
        <button
          type="submit"
          className="bg-ink hover:bg-ink/85 rounded-lg px-5 py-2.5 text-[0.9375rem] font-semibold text-white transition-colors"
        >
          {form.submit}
        </button>
      </div>
    </form>
  );
}
