import React from 'react';
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { Character } from '../character/registry';
import { colors, displayFamily, fontFamily } from '../theme';
import { Captions } from './Captions';
import type { LessonManifest, SceneManifest } from '../types';

// Common chrome for every scene: black-lacquer 60s-aviation backdrop, bronze
// winged brand placard, lesson progress bar, Duke, captions. Every scene
// whips in and rides a slow constant zoom so nothing ever sits still.

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

  const lastCaption = scene.captions[scene.captions.length - 1];
  const talking = lastCaption ? frame < lastCaption.endFrame : false;

  const progress = (sceneStartFrame + frame) / lesson.durationInFrames;

  // Whip-in: content slams up into place over ~8 frames…
  const whip = spring({ frame, fps, config: { damping: 15, stiffness: 260 } });
  // …then the whole layer slow-zooms for constant motion.
  const zoom = interpolate(frame, [0, scene.durationInFrames], [1, 1.04]);
  const dukeIn = spring({ frame: frame - 2, fps, config: { damping: 12, stiffness: 240 } });

  return (
    <AbsoluteFill style={{ background: colors.bg, fontFamily }}>
      {/* warm cockpit glow + faint machined grid */}
      <AbsoluteFill
        style={{
          backgroundImage:
            'radial-gradient(ellipse 90% 60% at 50% 28%, rgba(200,154,91,0.10), transparent 70%),' +
            'repeating-linear-gradient(0deg, transparent, transparent 79px, rgba(201,207,212,0.03) 80px),' +
            'repeating-linear-gradient(90deg, transparent, transparent 79px, rgba(201,207,212,0.03) 80px)',
        }}
      />
      <AbsoluteFill
        style={{
          background:
            'radial-gradient(ellipse 120% 100% at 50% 45%, transparent 55%, rgba(0,0,0,0.6) 100%)',
        }}
      />

      {/* bronze winged brand placard + episode counter */}
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
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            background: 'linear-gradient(165deg, rgba(255,255,255,0.07), rgba(255,255,255,0) 45%), #14110C',
            border: `2px solid ${colors.bronze}`,
            borderRadius: 10,
            padding: '10px 22px',
          }}
        >
          <svg width={44} height={20} viewBox="0 0 44 20">
            <path d="M 22 4 L 27 10 L 44 13 L 27 13 L 22 17 L 17 13 L 0 13 L 17 10 Z" fill={colors.bronze} />
          </svg>
          <span
            style={{
              fontFamily: displayFamily,
              fontWeight: 600,
              fontSize: 32,
              letterSpacing: '0.14em',
              color: colors.ink,
            }}
          >
            IFR <span style={{ color: colors.bronze }}>IN 30</span>
          </span>
        </div>
        <div
          style={{
            fontFamily: displayFamily,
            fontWeight: 500,
            fontSize: 30,
            letterSpacing: '0.24em',
            color: colors.inkDim,
          }}
        >
          EP {String(lesson.index + 1).padStart(2, '0')}
        </div>
      </div>

      {/* lesson progress bar — aluminum track, bronze fill */}
      <div
        style={{
          position: 'absolute',
          top: 46,
          left: 60,
          right: 60,
          height: 6,
          borderRadius: 3,
          background: 'rgba(201,207,212,0.18)',
        }}
      >
        <div
          style={{
            width: `${Math.min(100, progress * 100)}%`,
            height: '100%',
            borderRadius: 3,
            background: colors.bronze,
          }}
        />
      </div>

      {/* scene content: whip-in + constant slow zoom */}
      <AbsoluteFill
        style={{
          paddingTop: 150,
          transform: `translateY(${interpolate(whip, [0, 1], [90, 0])}px) scale(${
            interpolate(whip, [0, 1], [1.05, 1]) * zoom
          })`,
          opacity: interpolate(whip, [0, 0.4], [0, 1], { extrapolateRight: 'clamp' }),
        }}
      >
        {children}
      </AbsoluteFill>

      {/* Duke pops in fast */}
      {position !== 'hidden' && (
        <div
          style={{
            position: 'absolute',
            ...positions[position].style,
            transform: `translateY(${interpolate(dukeIn, [0, 1], [120, 0])}px)`,
          }}
        >
          <Character
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
