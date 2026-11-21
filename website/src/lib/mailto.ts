type MailtoInput = {
  to: string;
  subject: string;
  body: string;
};

/** Builds a `mailto:` link with an encoded subject and body. */
export function buildMailto({ to, subject, body }: MailtoInput): string {
  const query = new URLSearchParams({ subject, body }).toString().replaceAll("+", "%20");
  return `mailto:${to}?${query}`;
}
