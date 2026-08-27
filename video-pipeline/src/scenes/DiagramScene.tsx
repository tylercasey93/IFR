import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { diagramRegistry } from '../graphics/registry';
import { colors, type } from '../theme';
import type { SceneManifest } from '../types';

// A framed animated diagram with supporting text lines beneath it.

export const DiagramScene: React.FC<{ scene: SceneManifest }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const panelIn = spring({ frame, fps, config: { damping: 14, stiffness: 120 } });
  const lines = scene.onScreenText ?? [];

  const Diagram = scene.diagram ? diagramRegistry[scene.diagram.type] : undefined;

  return (
    <div style={{ padding: '30px 60px 0' }}>
      <div
        style={{
          background: colors.panel,
          border: `2px solid ${colors.panelEdge}`,
          borderRadius: 28,
          height: 820,
          overflow: 'hidden',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          opacity: panelIn,
          transform: `translateY(${interpolate(panelIn, [0, 1], [50, 0])}px)`,
        }}
      >
        {Diagram ? <Diagram {...(scene.diagram?.props ?? {})} /> : null}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18, marginTop: 28 }}>
        {lines.map((line, i) => {
          const lineIn = spring({
            frame: frame - 12 - i * 12,
            fps,
            config: { damping: 14, stiffness: 140 },
          });
          return (
            <div
              key={i}
              style={{
                ...type.bullet,
                fontSize: 44,
                color: i === 0 ? colors.green : colors.ink,
                opacity: lineIn,
                transform: `translateX(${interpolate(lineIn, [0, 1], [50, 0])}px)`,
              }}
            >
              {line}
            </div>
          );
        })}
      </div>
    </div>
  );
};
