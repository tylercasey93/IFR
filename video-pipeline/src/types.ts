// Shared types for the render manifest produced by scripts/gen-manifest.mjs.
// The manifest bakes per-scene durations and caption timings at build time so
// compositions are fully deterministic.

export type SceneKind = 'title' | 'bullets' | 'diagram' | 'recap' | 'sources';

export type DukePose = 'stand' | 'point' | 'coffeeSip' | 'armsCrossed';
export type DukeExpression = 'neutral' | 'deadpan' | 'eyebrowRaise' | 'grin' | 'squint';
export type DukePosition = 'left' | 'right' | 'center' | 'corner' | 'hidden';

export type DukeDirection = {
  pose?: DukePose;
  expression?: DukeExpression;
  position?: DukePosition;
};

export type DiagramSpec = {
  type: string;
  props?: Record<string, unknown>;
};

export type CaptionChunk = {
  text: string;
  startFrame: number;
  endFrame: number;
};

export type SceneManifest = {
  id: string;
  kind: SceneKind;
  narration: string;
  onScreenText?: string[];
  diagram?: DiagramSpec;
  duke?: DukeDirection;
  durationInFrames: number;
  /** Path under public/ for staticFile(), or null when rendering captions-only. */
  audioSrc: string | null;
  captions: CaptionChunk[];
};

export type LessonManifest = {
  id: string;
  index: number;
  title: string;
  topicArea: string;
  hook: string;
  references: {
    acs: string[];
    faa: { source: string; title: string };
  };
  scenes: SceneManifest[];
  durationInFrames: number;
};

export type RenderManifest = {
  fps: number;
  width: number;
  height: number;
  /** Path under public/ for the music bed, or null if not generated yet. */
  musicSrc: string | null;
  lessons: LessonManifest[];
};
