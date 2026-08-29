import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { panelStyle, Rivets } from './chrome';
import { colors, displayFamily, type } from '../theme';
import type { SceneManifest } from '../types';

// Retrieval-practice beat: Duke throws the viewer a question and the video
// actually waits. A "YOUR AIRPLANE" placard hands them the problem, and a
// countdown ring runs through the silent think-time at the end of the scene.

export const ChallengeScene: React.FC<{ scene: SceneManifest }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const cardIn = spring({ frame, fps, config: { damping: 12, stiffness: 260 } });

  const pauseFrames = Math.round((scene.pauseSec ?? 3) * fps);
  const pauseStart = scene.durationInFrames - pauseFrames;
  const inPause = frame >= pauseStart;
  const pauseT = inPause ? (frame - pauseStart) / pauseFrames : 0;

  const question = scene.onScreenText?.[0] ?? '';

  // countdown ring geometry
  const R = 64;
  const circumference = 2 * Math.PI * R;

  return (
    <div style={{ padding: '60px 70px 0' }}>
      <div
        style={{
          display: 'inline-block',
          fontFamily: displayFamily,
          fontWeight: 600,
          fontSize: 30,
          letterSpacing: '0.28em',
          color: colors.bg,
          background: colors.bronze,
          borderRadius: 8,
          padding: '10px 24px',
          marginBottom: 36,
          transform: `scale(${0.8 + cardIn * 0.2})`,
          opacity: cardIn,
        }}
      >
        YOUR AIRPLANE
      </div>

      <div
        style={{
          ...panelStyle,
          position: 'relative',
          borderRadius: 28,
          padding: '48px 44px',
          opacity: cardIn,
          transform: `translateY(${interpolate(cardIn, [0, 1], [50, 0])}px)`,
        }}
      >
        <Rivets inset={12} />
        <div style={{ ...type.bullet, fontSize: 58, color: colors.ink }}>{question}</div>
        {scene.onScreenText?.slice(1).map((line, i) => (
          <div key={i} style={{ ...type.chip, color: colors.inkDim, marginTop: 22 }}>
            {line}
          </div>
        ))}
      </div>

      {inPause && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 28, marginTop: 44 }}>
          <svg width={148} height={148} viewBox="0 0 148 148">
            <circle cx={74} cy={74} r={R} fill="none" stroke="rgba(201,207,212,0.2)" strokeWidth={10} />
            <circle
              cx={74}
              cy={74}
              r={R}
              fill="none"
              stroke={colors.bronze}
              strokeWidth={10}
              strokeLinecap="round"
              strokeDasharray={circumference}
              strokeDashoffset={circumference * pauseT}
              transform="rotate(-90, 74, 74)"
            />
            <text
              x={74}
              y={92}
              textAnchor="middle"
              fill={colors.ink}
              fontFamily={displayFamily}
              fontWeight={600}
              fontSize={52}
            >
              {Math.max(1, Math.ceil((scene.pauseSec ?? 3) * (1 - pauseT)))}
            </text>
          </svg>
          <div style={{ ...type.subtitle, color: colors.bronze }}>Lock in your answer.</div>
        </div>
      )}
    </div>
  );
};
