import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors, type } from '../theme';
import type { SceneManifest } from '../types';

// Staggered big-type bullets. Reveal timing spreads across the narrated
// portion of the scene so lines land roughly as Duke reaches them.

export const BulletScene: React.FC<{ scene: SceneManifest }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const lines = scene.onScreenText ?? [];
  const lastCaptionEnd = scene.captions[scene.captions.length - 1]?.endFrame ?? scene.durationInFrames;
  const window = Math.max(1, lastCaptionEnd * 0.75);

  return (
    <div style={{ padding: '60px 70px 0', display: 'flex', flexDirection: 'column', gap: 34 }}>
      {lines.map((line, i) => {
        const start = (i / Math.max(1, lines.length)) * window;
        const inSpring = spring({
          frame: frame - start,
          fps,
          config: { damping: 14, stiffness: 130 },
        });
        return (
          <div
            key={i}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 26,
              opacity: inSpring,
              transform: `translateX(${interpolate(inSpring, [0, 1], [70, 0])}px)`,
            }}
          >
            <div
              style={{
                width: 16,
                height: 16,
                borderRadius: 4,
                background: colors.green,
                flexShrink: 0,
                transform: 'rotate(45deg)',
              }}
            />
            <div
              style={{
                ...type.bullet,
                color: colors.ink,
                background: colors.panel,
                border: `2px solid ${colors.panelEdge}`,
                borderRadius: 20,
                padding: '20px 30px',
              }}
            >
              {line}
            </div>
          </div>
        );
      })}
    </div>
  );
};
