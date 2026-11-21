import {
  Ban,
  Bomb,
  Bot,
  Bug,
  Compass,
  Eye,
  Gauge,
  Hand,
  Lock,
  type LucideIcon,
  Mail,
  Pickaxe,
  Server,
  Shield,
  Sparkles,
  Trash2,
  User,
  Users,
} from "lucide-react";

/**
 * Icons referenced by name from the JSON content. One place to add an icon;
 * components render `ICONS[name]` instead of inline SVG.
 */
export const ICONS = {
  ban: Ban,
  bomb: Bomb,
  bot: Bot,
  bug: Bug,
  compass: Compass,
  eye: Eye,
  gauge: Gauge,
  hand: Hand,
  lock: Lock,
  mail: Mail,
  pickaxe: Pickaxe,
  server: Server,
  shield: Shield,
  sparkles: Sparkles,
  trash: Trash2,
  user: User,
  users: Users,
} satisfies Record<string, LucideIcon>;

export type IconName = keyof typeof ICONS;
