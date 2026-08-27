import React from 'react';
import { interpolate, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';

// An altimeter winding down toward a DA bug, with a digital readout.

type Props = { da?: number };

export const AltimeterMinimums: React.FC<Props> = ({ da = 200 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const alt = Math.round(
    interpolate(frame, [8, fps * 4], [1500, da], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    })
  );
  // Needle: one revolution per 1,000 ft.
  const needleDeg = ((alt % 1000) / 1000) * 360;
  const bugDeg = ((da % 1000) / 1000) * 360;
  const atMins = alt <= da + 5;

  return (
    <svg width={960} height={780} viewBox="0 0 960 780">
      <circle cx={480} cy={360} r={270} fill="#10140F" stroke={atMins ? colors.amber : colors.panelEdge} strokeWidth={atMins ? 10 : 6} />
      {Array.from({ length: 10 }, (_, i) => {
        const deg = i * 36 - 90;
        const rad = (deg * Math.PI) / 180;
        return (
          <g key={i}>
            <line
              x1={480 + Math.cos(rad) * 225}
              y1={360 + Math.sin(rad) * 225}
              x2={480 + Math.cos(rad) * 250}
              y2={360 + Math.sin(rad) * 250}
              stroke={colors.ink}
              strokeWidth={5}
            />
            <text
              x={480 + Math.cos(rad) * 190}
              y={360 + Math.sin(rad) * 190 + 14}
              fill={colors.ink}
              fontSize={40}
              fontWeight={700}
              textAnchor="middle"
            >
              {i}
            </text>
          </g>
        );
      })}
      {/* DA bug */}
      <g transform={`rotate(${bugDeg}, 480, 360)`}>
        <path d="M 480 96 L 498 128 L 462 128 Z" fill={colors.amber} />
      </g>
      {/* needle */}
      <g transform={`rotate(${needleDeg}, 480, 360)`}>
        <line x1={480} y1={360} x2={480} y2={140} stroke={colors.ink} strokeWidth={10} strokeLinecap="round" />
      </g>
      <circle cx={480} cy={360} r={16} fill={colors.ink} />
      {/* readout */}
      <rect x={330} y={660} width={300} height={90} rx={16} fill={colors.panel} stroke={atMins ? colors.amber : colors.panelEdge} strokeWidth={4} />
      <text x={480} y={722} fill={atMins ? colors.amber : colors.green} fontSize={52} fontWeight={800} textAnchor="middle">
        {alt.toLocaleString('en-US')} ft
      </text>
      {atMins && (
        <text x={480} y={620} fill={colors.amber} fontSize={40} fontWeight={800} textAnchor="middle">
          MINIMUMS
        </text>
      )}
    </svg>
  );
};
