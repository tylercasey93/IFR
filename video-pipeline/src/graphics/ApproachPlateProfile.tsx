import React from 'react';
import { interpolate, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';

// Stylized approach-plate teaching graphic.
//  highlight="top":     briefing-strip boxes (freqs / course / runway / notes)
//  highlight="profile": profile view with FAF, stepdown, MAP
//  highlight="ils":     localizer + glideslope beams
//  highlight="da":      guided descent to a DA with the decide point
//  highlight="mda":     dive-and-drive to an MDA floor

type Props = { highlight?: 'top' | 'profile' | 'ils' | 'da' | 'mda' };

const GROUND_Y = 620;
const RWY_X = 780;

const Ground: React.FC = () => (
  <g>
    <line x1={40} y1={GROUND_Y} x2={920} y2={GROUND_Y} stroke={colors.inkDim} strokeWidth={4} />
    <rect x={RWY_X} y={GROUND_Y - 8} width={130} height={8} fill={colors.ink} />
    <text x={RWY_X + 65} y={GROUND_Y + 42} fill={colors.inkDim} fontSize={26} fontWeight={600} textAnchor="middle">
      RWY
    </text>
  </g>
);

export const ApproachPlateProfile: React.FC<Props> = ({ highlight = 'profile' }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const draw = interpolate(frame, [6, fps * 2], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  if (highlight === 'top') {
    const rows = [
      ['APP CRS 273°', 'LOC 109.9', 'RWY 27'],
      ['NOTES: read me. Seriously.'],
      ['MISSED: climb 2400, then …'],
    ];
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        {rows.map((cells, r) => {
          const rowIn = interpolate(frame, [8 + r * 14, 24 + r * 14], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          });
          return (
            <g key={r} opacity={rowIn} transform={`translate(0, ${120 + r * 130})`}>
              {cells.map((cell, c) => {
                const w = cells.length === 1 ? 800 : 256;
                return (
                  <g key={c} transform={`translate(${80 + c * 272}, 0)`}>
                    <rect width={w} height={100} rx={14} fill="#10140F" stroke={r === 0 ? colors.green : colors.amber} strokeWidth={4} />
                    <text x={24} y={62} fill={colors.ink} fontSize={34} fontWeight={700}>
                      {cell}
                    </text>
                  </g>
                );
              })}
            </g>
          );
        })}
        <text x={80} y={620} fill={colors.inkDim} fontSize={32} fontWeight={600}>
          The briefing strip: everything above the plan view,
        </text>
        <text x={80} y={668} fill={colors.inkDim} fontSize={32} fontWeight={600}>
          read left to right, top to bottom.
        </text>
      </svg>
    );
  }

  if (highlight === 'ils') {
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        <Ground />
        {/* glideslope beam */}
        <path
          d={`M ${RWY_X + 30} ${GROUND_Y} L 80 220 L 80 320 Z`}
          fill={colors.green}
          opacity={0.18 * draw}
        />
        <line x1={RWY_X + 30} y1={GROUND_Y} x2={80} y2={270} stroke={colors.green} strokeWidth={6} strokeDasharray="18 12" opacity={draw} />
        <text x={110} y={240} fill={colors.green} fontSize={34} fontWeight={800} opacity={draw}>
          GLIDESLOPE ~3°
        </text>
        {/* localizer wedge (plan-view inset) */}
        <g transform="translate(80, 420)" opacity={draw}>
          <path d="M 620 60 L 0 12 L 0 108 Z" fill={colors.amber} opacity={0.22} />
          <line x1={620} y1={60} x2={0} y2={60} stroke={colors.amber} strokeWidth={5} />
          <text x={10} y={-6} fill={colors.amber} fontSize={34} fontWeight={800}>
            LOCALIZER (left/right)
          </text>
        </g>
      </svg>
    );
  }

  if (highlight === 'da') {
    const planeT = interpolate(frame, [10, fps * 3.2], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    const daY = GROUND_Y - 120;
    const px = interpolate(planeT, [0, 1], [120, RWY_X - 180]);
    const py = interpolate(planeT, [0, 1], [200, daY]);
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        <Ground />
        <line x1={60} y1={daY} x2={900} y2={daY} stroke={colors.amber} strokeWidth={5} strokeDasharray="20 14" />
        <text x={64} y={daY - 16} fill={colors.amber} fontSize={34} fontWeight={800}>
          DA — decide HERE
        </text>
        <line x1={120} y1={200} x2={RWY_X + 20} y2={GROUND_Y - 6} stroke={colors.green} strokeWidth={6} strokeDasharray="16 10" />
        <Plane x={px} y={py} angle={26} />
        {planeT > 0.96 && (
          <text x={px + 30} y={py - 30} fill={colors.ink} fontSize={36} fontWeight={800}>
            land… or miss?
          </text>
        )}
      </svg>
    );
  }

  if (highlight === 'mda') {
    const t = interpolate(frame, [10, fps * 3.5], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    const mdaY = GROUND_Y - 150;
    // descend, then level at the MDA to the MAP
    const px = interpolate(t, [0, 1], [110, RWY_X - 60]);
    const py = px < 430 ? interpolate(px, [110, 430], [220, mdaY]) : mdaY;
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        <Ground />
        <line x1={60} y1={mdaY} x2={900} y2={mdaY} stroke={colors.amber} strokeWidth={6} />
        <text x={64} y={mdaY - 16} fill={colors.amber} fontSize={34} fontWeight={800}>
          MDA — hard floor
        </text>
        <path d={`M 110 220 L 430 ${mdaY} L ${RWY_X - 40} ${mdaY}`} fill="none" stroke={colors.green} strokeWidth={6} strokeDasharray="16 10" />
        <text x={520} y={mdaY + 52} fill={colors.inkDim} fontSize={30} fontWeight={600}>
          level to the MAP
        </text>
        <Plane x={px} y={py - 8} angle={px < 430 ? 24 : 0} />
      </svg>
    );
  }

  // default: profile view with FAF / stepdown / MAP
  return (
    <svg width={960} height={780} viewBox="0 0 960 780">
      <Ground />
      <path
        d={`M 90 200 L 340 200 L 560 400 L 560 400 L ${RWY_X - 30} 470`}
        fill="none"
        stroke={colors.green}
        strokeWidth={7}
        pathLength={100}
        strokeDasharray={100}
        strokeDashoffset={100 - draw * 100}
      />
      {/* FAF maltese cross */}
      <g transform="translate(340, 200)" opacity={draw}>
        <path d="M 0 -22 L 7 -7 L 22 0 L 7 7 L 0 22 L -7 7 L -22 0 L -7 -7 Z" fill={colors.amber} />
        <text x={-30} y={-38} fill={colors.amber} fontSize={32} fontWeight={800}>FAF</text>
      </g>
      <text x={560} y={360} fill={colors.inkDim} fontSize={30} fontWeight={600} opacity={draw}>
        stepdown
      </text>
      <g transform={`translate(${RWY_X - 30}, 470)`} opacity={draw}>
        <circle r={10} fill={colors.red} />
        <text x={-24} y={-24} fill={colors.red} fontSize={32} fontWeight={800}>MAP</text>
      </g>
    </svg>
  );
};

const Plane: React.FC<{ x: number; y: number; angle: number }> = ({ x, y, angle }) => (
  <g transform={`translate(${x}, ${y}) rotate(${angle})`}>
    <path d="M 34 0 L -18 -10 L -10 0 L -18 10 Z" fill={colors.ink} />
  </g>
);
