import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors, type } from '../theme';
import type { SceneManifest } from '../types';

// Checklist-style recap: items tick themselves off, cockpit-flow style.

export const RecapScene: React.FC<{ scene: SceneManifest }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const lines = scene.onScreenText ?? [];

  return (
    <div style={{ padding: '50px 70px 0' }}>
      <div
        style={{
          ...type.placard,
          color: colors.inkDim,
          marginBottom: 30,
        }}
      >
        CHECKLIST
      </div>
      <div
        style={{
          background: colors.panel,
          border: `2px solid ${colors.panelEdge}`,
          borderRadius: 24,
          padding: '14px 30px',
        }}
      >
        {lines.map((line, i) => {
          const start = 6 + i * Math.max(10, 26 - lines.length * 2);
          const tick = spring({
            frame: frame - start,
            fps,
            config: { damping: 12, stiffness: 180 },
          });
          return (
            <div
              key={i}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 26,
                padding: '22px 0',
                borderBottom: i < lines.length - 1 ? `1px solid ${colors.panelEdge}` : 'none',
                opacity: interpolate(tick, [0, 0.3], [0.25, 1], { extrapolateRight: 'clamp' }),
              }}
            >
              <svg width={44} height={44} viewBox="0 0 44 44" style={{ flexShrink: 0 }}>
                <rect x={3} y={3} width={38} height={38} rx={10} fill="none" stroke={colors.green} strokeWidth={3.5} />
                <path
                  d="M 12 23 L 19 30 L 32 15"
                  fill="none"
                  stroke={colors.green}
                  strokeWidth={5}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeDasharray={34}
                  strokeDashoffset={34 - tick * 34}
                />
              </svg>
              <div style={{ ...type.bullet, color: colors.ink }}>{line}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
