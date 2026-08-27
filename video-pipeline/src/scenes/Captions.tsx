import React from 'react';
import { spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors, type } from '../theme';
import type { CaptionChunk } from '../types';

// Karaoke-style captions: one chunk at a time, popping in near the bottom of
// the frame (kept above typical feed UI overlays).

export const Captions: React.FC<{ captions: CaptionChunk[] }> = ({ captions }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const current = captions.find((c) => frame >= c.startFrame && frame < c.endFrame);
  if (!current) return null;

  const pop = spring({
    frame: frame - current.startFrame,
    fps,
    config: { damping: 12, stiffness: 200 },
    durationInFrames: 8,
  });

  return (
    <div
      style={{
        position: 'absolute',
        left: 60,
        right: 60,
        bottom: 210,
        display: 'flex',
        justifyContent: 'center',
        pointerEvents: 'none',
      }}
    >
      <div
        style={{
          ...type.caption,
          color: colors.ink,
          textAlign: 'center',
          transform: `scale(${0.9 + pop * 0.1})`,
          textShadow: '0 4px 24px rgba(0,0,0,0.9), 0 2px 6px rgba(0,0,0,0.8)',
          background: 'rgba(11,14,12,0.55)',
          borderRadius: 24,
          padding: '18px 34px',
        }}
      >
        {current.text}
      </div>
    </div>
  );
};
