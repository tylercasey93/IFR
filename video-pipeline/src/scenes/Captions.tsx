import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors, type } from '../theme';
import type { CaptionChunk } from '../types';

// Karaoke-style captions: one chunk at a time, popping hard near the bottom
// of the frame. Number/reg/acronym tokens get the bronze highlight.

const isKeyToken = (word: string) =>
  /\d/.test(word) || (/^[A-Z]{2,}/.test(word.replace(/[^A-Za-z0-9]/g, '')) && word.length > 1);

export const Captions: React.FC<{ captions: CaptionChunk[] }> = ({ captions }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const index = captions.findIndex((c) => frame >= c.startFrame && frame < c.endFrame);
  if (index < 0) return null;
  const current = captions[index];

  const pop = spring({
    frame: frame - current.startFrame,
    fps,
    config: { damping: 11, stiffness: 320 },
    durationInFrames: 7,
  });
  const tilt = (index % 2 === 0 ? 1 : -1) * interpolate(pop, [0, 1], [2.2, 0.8]);

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
          transform: `scale(${0.82 + pop * 0.18}) rotate(${tilt}deg)`,
          textShadow: '0 4px 24px rgba(0,0,0,0.9), 0 2px 6px rgba(0,0,0,0.8)',
          background: 'rgba(12,11,9,0.6)',
          borderRadius: 24,
          padding: '18px 34px',
        }}
      >
        {current.text.split(' ').map((word, i) => (
          <span key={i} style={{ color: isKeyToken(word) ? colors.bronze : colors.ink }}>
            {word}{' '}
          </span>
        ))}
      </div>
    </div>
  );
};
