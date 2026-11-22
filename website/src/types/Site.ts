export type Site = {
  name: string;
  storeTitle: string;
  /** Search result title (~60 chars) and description (~155 chars). */
  seoTitle: string;
  seoDescription: string;
  /** schema.org genres. */
  genres: string[];
  tagline: string;
  description: string;
  developer: string;
  location: string;
  contactEmail: string;
  packageName: string;
  playStoreUrl: string;
  policyLastUpdated: string;
  keywords: string[];
  /** Leave a link empty ("") to hide it. */
  social: { github: string; instagram: string; facebook: string; website: string };
};
