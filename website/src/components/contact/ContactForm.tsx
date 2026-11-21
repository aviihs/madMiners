"use client";

import { type FormEvent, useState } from "react";

import { site } from "@/lib/content";
import { buildMailto } from "@/lib/mailto";
import type { ContactContent } from "@/types/Contact";

const FIELD_CLASSES =
  "mt-2 w-full rounded-2xl border border-hairline bg-bg/70 px-4 py-3 text-text placeholder:text-faint focus:border-gold/60 focus:outline-none";

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
    <form onSubmit={handleSubmit} className="border-hairline bg-surface/70 rounded-3xl border p-6 sm:p-8">
      <h2 className="text-3xl">{form.title}</h2>
      <p className="text-muted mt-2 text-sm">{form.note}</p>

      <label className="mt-6 block font-extrabold">
        Topic
        <select value={topic} onChange={(event) => setTopic(event.target.value)} className={FIELD_CLASSES}>
          {form.topics.map((option) => (
            <option key={option}>{option}</option>
          ))}
        </select>
      </label>

      <label className="mt-5 block font-extrabold">
        In-game username <span className="text-faint font-semibold">(optional)</span>
        <input
          value={username}
          onChange={(event) => setUsername(event.target.value)}
          maxLength={24}
          placeholder="e.g. Sagar_07"
          className={FIELD_CLASSES}
        />
      </label>

      <label className="mt-5 block font-extrabold">
        Message
        <textarea
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          required
          rows={6}
          maxLength={2000}
          placeholder="Tell us what happened or what you'd like to see…"
          className={FIELD_CLASSES}
        />
      </label>

      <button
        type="submit"
        className="bg-gold font-display text-on-gold mt-6 w-full rounded-2xl px-6 py-3.5 text-lg transition hover:brightness-110"
      >
        {form.submit}
      </button>
    </form>
  );
}
