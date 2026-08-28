import React from 'react';
import { interpolate, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';

// Holding pattern (standard right turns, inbound course westbound to the fix
// at left). stage="sectors" shades the three entry sectors split by the 70°
// line; stage="entry" animates the flight path for one entry type.

type Props = {
  stage?: 'sectors' | 'entry';
  entryHighlight?: 'direct' | 'parallel' | 'teardrop';
  inboundCourse?: number;
};

const FIX = { x: 330, y: 470 };

// Racetrack: inbound leg along y=470 from x=690 to the fix, right turns,
// outbound leg along y=310.
const racetrack =
  `M 690 470 L ${FIX.x} 470 ` +
  `A 80 80 0 0 1 ${FIX.x} 310 ` +
  `L 690 310 A 80 80 0 0 1 690 470 Z`;

const entryPaths: Record<string, string> = {
  // From the "big slice": arrive from the southeast, cross the fix, turn outbound.
  direct: `M 800 640 L 360 486 L ${FIX.x} 470 A 80 80 0 0 1 ${FIX.x} 310 L 560 310`,
  // From beyond the fix on the holding side: cross, 30° into protected airspace, turn back.
  teardrop: `M 60 640 L ${FIX.x} 470 L 560 388 A 62 62 0 0 1 610 470 L 420 470`,
  // From the non-holding side: cross, parallel the course outbound, turn back to the holding side.
  parallel: `M 60 560 L ${FIX.x} 470 L 640 470 M 640 470 A 60 60 0 0 0 660 360 L 470 430`,
};

export const HoldingPattern: React.FC<Props> = ({
  stage = 'sectors',
  entryHighlight = 'direct',
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const draw = interpolate(frame, [8, fps * 2.2], [100, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const sectorIn = interpolate(frame, [10, 30], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <svg width={960} height={780} viewBox="0 0 960 780">
      <defs>
        <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M 0 0 L 10 5 L 0 10 z" fill={colors.amber} />
        </marker>
      </defs>

      {stage === 'sectors' && (
        <g opacity={sectorIn}>
          {/* 70° line through the fix (relative to the inbound course, which is horizontal) */}
          <line
            x1={FIX.x - 380 * Math.cos(1.2217)}
            y1={FIX.y + 380 * Math.sin(1.2217)}
            x2={FIX.x + 380 * Math.cos(1.2217)}
            y2={FIX.y - 380 * Math.sin(1.2217)}
            stroke={colors.inkDim}
            strokeWidth={4}
            strokeDasharray="14 12"
          />
          <text x={FIX.x + 150} y={FIX.y - 330} fill={colors.inkDim} fontSize={30} fontWeight={600}>
            70° line
          </text>
          {/* sector shading: direct (big slice), teardrop (holding side), parallel (far side) */}
          <path d={`M ${FIX.x} ${FIX.y} L 960 250 L 960 780 L 100 780 Z`} fill={colors.bronze} opacity={0.14} />
          <path d={`M ${FIX.x} ${FIX.y} L 100 780 L 0 780 L 0 560 Z`} fill={colors.red} opacity={0.18} />
          <path d={`M ${FIX.x} ${FIX.y} L 0 560 L 0 0 L 960 0 L 960 250 Z`} fill={colors.aluminum} opacity={0.1} />
          <text x={620} y={640} fill={colors.bronze} fontSize={38} fontWeight={800}>DIRECT</text>
          <text x={60} y={710} fill="#D96A54" fontSize={38} fontWeight={800}>TEARDROP</text>
          <text x={90} y={120} fill={colors.aluminum} fontSize={38} fontWeight={800}>PARALLEL</text>
        </g>
      )}

      {/* racetrack */}
      <path d={racetrack} fill="none" stroke={colors.ink} strokeWidth={7} opacity={0.9} />
      {/* inbound arrow + label */}
      <line x1={620} y1={470} x2={480} y2={470} stroke={colors.ink} strokeWidth={0} markerEnd="url(#arrow)" />
      <text x={430} y={520} fill={colors.inkDim} fontSize={28} fontWeight={600}>
        inbound
      </text>

      {/* the fix */}
      <g transform={`translate(${FIX.x}, ${FIX.y})`}>
        <path d="M 0 -18 L 16 10 L -16 10 Z" fill={colors.amber} />
        <text x={-30} y={52} fill={colors.amber} fontSize={30} fontWeight={700}>FIX</text>
      </g>

      {stage === 'entry' && (
        <path
          d={entryPaths[entryHighlight] ?? entryPaths.direct}
          fill="none"
          stroke={colors.green}
          strokeWidth={9}
          strokeLinecap="round"
          pathLength={100}
          strokeDasharray={100}
          strokeDashoffset={draw}
          markerEnd="url(#arrow)"
        />
      )}
    </svg>
  );
};
