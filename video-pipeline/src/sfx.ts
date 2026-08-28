// Sound-effect availability, resolved at bundle time from the manifest so a
// missing wav (make-music.mjs not run) never breaks a render.
import manifestJson from './generated/manifest.json';

type SfxFlags = { sfx?: { whoosh?: boolean; ding?: boolean } };
const flags = (manifestJson as SfxFlags).sfx ?? {};

export const whooshSrc = flags.whoosh ? 'audio/sfx-whoosh.wav' : null;
export const dingSrc = flags.ding ? 'audio/sfx-ding.wav' : null;
