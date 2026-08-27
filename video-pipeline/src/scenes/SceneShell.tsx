import React from 'react';
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from 'remotion';
import { Duke } from '../character/Duke';
import { colors, fontFamily } from '../theme';
import { Captions } from './Captions';
import type { LessonManifest, SceneManifest } from '../types';

// Common chrome for every scene: instrument-panel background, brand chip,
// lesson progress bar, Duke (positioned per scene direction), and captions.

const positions = {
  center: { size: 660, style: { bottom: 330, left: '50%', marginLeft: -257 } },
  left: { size: 540, style: { bottom: 300, left: 30 } },
  right: { size: 540, style: { bottom: 300, right: 30 } },
  corner: { size: 400, style: { bottom: 290, right: 8 } },
} as const;

export const SceneShell: React.FC<{
  lesson: LessonManifest;
  scene: SceneManifest;
  sceneStartFrame: number;
  children: React.ReactNode;
}> = ({ lesson, scene, sceneStartFrame, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const duke = scene.duke ?? {};
  const position = duke.position ?? 'corner';

  // Duke "talks" while the narration for this scene is running (captions window).
  const lastCaption = scene.captions[scene.captions.length - 1];
  const talking = lastCaption ? frame < lastCaption.endFrame : false;

  const progress = (sceneStartFrame + frame) / lesson.durationInFrames;

  return (
    <AbsoluteFill style={{ background: colors.bg, fontFamily }}>
      {/* subtle instrument-grid backdrop */}
      <AbsoluteFill
        style={{
          backgroundImage:
            'radial-gradient(ellipse 90% 60% at 50% 30%, rgba(92,199,140,0.07), transparent 70%),' +
            'repeating-linear-gradient(0deg, transparent, transparent 79px, rgba(255,255,255,0.025) 80px),' +
            'repeating-linear-gradient(90deg, transparent, transparent 79px, rgba(255,255,255,0.025) 80px)',
        }}
      />
      {/* vignette */}
      <AbsoluteFill
        style={{
          background:
            'radial-gradient(ellipse 120% 100% at 50% 45%, transparent 55%, rgba(0,0,0,0.55) 100%)',
        }}
      />

      {/* brand chip + episode number */}
      <div
        style={{
          position: 'absolute',
          top: 70,
          left: 60,
          right: 60,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            fontWeight: 800,
            fontSize: 34,
            letterSpacing: '0.08em',
            color: colors.ink,
            background: colors.panel,
            border: `2px solid ${colors.panelEdge}`,
            borderRadius: 16,
            padding: '12px 24px',
          }}
        >
          IFR <span style={{ color: colors.green }}>in 30</span>
        </div>
        <div
          style={{
            fontWeight: 600,
            fontSize: 30,
            letterSpacing: '0.2em',
            color: colors.inkDim,
          }}
        >
          EP {String(lesson.index + 1).padStart(2, '0')}
        </div>
      </div>

      {/* lesson progress bar */}
      <div
        style={{
          position: 'absolute',
          top: 46,
          left: 60,
          right: 60,
          height: 6,
          borderRadius: 3,
          background: 'rgba(255,255,255,0.12)',
        }}
      >
        <div
          style={{
            width: `${Math.min(100, progress * 100)}%`,
            height: '100%',
            borderRadius: 3,
            background: colors.amber,
          }}
        />
      </div>

      {/* scene content */}
      <AbsoluteFill style={{ paddingTop: 150 }}>{children}</AbsoluteFill>

      {/* Duke */}
      {position !== 'hidden' && (
        <div style={{ position: 'absolute', ...positions[position].style }}>
          <Duke
            pose={duke.pose ?? 'stand'}
            expression={duke.expression ?? 'neutral'}
            talking={talking}
            size={positions[position].size}
          />
        </div>
      )}

      <Captions captions={scene.captions} />
    </AbsoluteFill>
  );
};
