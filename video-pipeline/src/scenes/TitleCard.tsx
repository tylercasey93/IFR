import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors, type } from '../theme';
import type { LessonManifest } from '../types';

export const TitleCard: React.FC<{ lesson: LessonManifest }> = ({ lesson }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleIn = spring({ frame, fps, config: { damping: 13, stiffness: 110 } });
  const hookIn = spring({ frame: frame - 10, fps, config: { damping: 14, stiffness: 110 } });
  const chipIn = spring({ frame: frame - 4, fps, config: { damping: 14, stiffness: 140 } });

  return (
    <div style={{ padding: '90px 70px 0' }}>
      <div
        style={{
          transform: `scale(${0.8 + chipIn * 0.2})`,
          opacity: chipIn,
          display: 'inline-block',
          ...type.placard,
          color: colors.amber,
          border: `2px solid ${colors.amber}`,
          borderRadius: 12,
          padding: '10px 22px',
          marginBottom: 40,
        }}
      >
        {lesson.topicArea.toUpperCase()}
      </div>
      <div
        style={{
          ...type.title,
          color: colors.ink,
          transform: `translateY(${interpolate(titleIn, [0, 1], [60, 0])}px)`,
          opacity: titleIn,
        }}
      >
        {lesson.title}
      </div>
      <div
        style={{
          ...type.subtitle,
          color: colors.green,
          marginTop: 42,
          transform: `translateY(${interpolate(hookIn, [0, 1], [40, 0])}px)`,
          opacity: hookIn,
        }}
      >
        {lesson.hook}
      </div>
    </div>
  );
};
