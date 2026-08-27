import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';

// Route/altitude teaching graphics.
//  variant="route":    AVEF priority chain for lost comms
//  variant="altitude": highest-of-three (MEA / Expected / Assigned)
//  variant="mea":      terrain with MEA vs MOCA (22 NM signal note)
//  variant="climb":    standard 200 ft/NM departure gradient

type Props = { variant?: 'route' | 'altitude' | 'mea' | 'climb' };

export const RouteAltitude: React.FC<Props> = ({ variant = 'route' }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  if (variant === 'route') {
    const items = [
      ['A', 'Assigned'],
      ['V', 'Vectored'],
      ['E', 'Expected'],
      ['F', 'Filed'],
    ];
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        {items.map(([letter, word], i) => {
          const inSpring = spring({ frame: frame - 8 - i * 14, fps, config: { damping: 13, stiffness: 140 } });
          const y = 90 + i * 160;
          return (
            <g key={letter} opacity={inSpring} transform={`translate(${(1 - inSpring) * 60}, 0)`}>
              <rect x={120} y={y} width={130} height={110} rx={20} fill={colors.green} opacity={0.9 - i * 0.14} />
              <text x={185} y={y + 78} fill="#0B0E0C" fontSize={64} fontWeight={800} textAnchor="middle">
                {letter}
              </text>
              <text x={290} y={y + 70} fill={colors.ink} fontSize={48} fontWeight={700}>
                {word}
              </text>
              {i < 3 && (
                <text x={168} y={y + 148} fill={colors.inkDim} fontSize={38} fontWeight={700}>
                  ↓ then
                </text>
              )}
            </g>
          );
        })}
        <text x={620} y={720} fill={colors.inkDim} fontSize={30} fontWeight={600}>in that order</text>
      </svg>
    );
  }

  if (variant === 'altitude') {
    const bars = [
      { label: 'MEA', value: 5000, h: 250 },
      { label: 'EXPECTED', value: 7000, h: 380, winner: true },
      { label: 'ASSIGNED', value: 6000, h: 310 },
    ];
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        {bars.map((bar, i) => {
          const grow = spring({ frame: frame - 8 - i * 10, fps, config: { damping: 14, stiffness: 120 } });
          const h = bar.h * grow;
          const x = 130 + i * 260;
          return (
            <g key={bar.label}>
              <rect
                x={x}
                y={640 - h}
                width={190}
                height={h}
                rx={16}
                fill={bar.winner ? colors.green : colors.panelEdge}
                stroke={bar.winner ? colors.green : colors.inkDim}
                strokeWidth={3}
              />
              <text x={x + 95} y={700} fill={colors.inkDim} fontSize={30} fontWeight={700} textAnchor="middle">
                {bar.label}
              </text>
              <text x={x + 95} y={640 - h - 18} fill={bar.winner ? colors.green : colors.ink} fontSize={40} fontWeight={800} textAnchor="middle" opacity={grow}>
                {bar.value.toLocaleString('en-US')}
              </text>
              {bar.winner && frame > 60 && (
                <text x={x + 95} y={640 - h - 76} fill={colors.amber} fontSize={44} fontWeight={800} textAnchor="middle">
                  ★ fly this
                </text>
              )}
            </g>
          );
        })}
        <text x={480} y={90} fill={colors.ink} fontSize={40} fontWeight={800} textAnchor="middle">
          highest of the three — per segment
        </text>
      </svg>
    );
  }

  if (variant === 'mea') {
    const lineIn = interpolate(frame, [8, 50], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        {/* terrain */}
        <path
          d="M 40 700 L 150 560 L 260 640 L 400 430 L 520 600 L 660 500 L 800 660 L 920 620 L 920 780 L 40 780 Z"
          fill="#26302B"
        />
        {/* MEA line */}
        <line x1={60} y1={300} x2={900} y2={300} stroke={colors.green} strokeWidth={7} opacity={lineIn} />
        <text x={70} y={276} fill={colors.green} fontSize={38} fontWeight={800} opacity={lineIn}>
          MEA — obstacles + signal
        </text>
        {/* MOCA line */}
        <line x1={60} y1={392} x2={900} y2={392} stroke={colors.amber} strokeWidth={6} strokeDasharray="18 12" opacity={lineIn} />
        <text x={70} y={442} fill={colors.amber} fontSize={38} fontWeight={800} opacity={lineIn}>
          MOCA — signal only ≤ 22 NM
        </text>
        {/* VOR + 22NM arc */}
        <g transform="translate(480, 700)" opacity={lineIn}>
          <path d="M 0 -20 L 17 -10 L 17 10 L 0 20 L -17 10 L -17 -10 Z" fill={colors.panel} stroke={colors.ink} strokeWidth={4} />
          <path d="M -220 -60 A 230 230 0 0 1 220 -60" fill="none" stroke={colors.inkDim} strokeWidth={3} strokeDasharray="10 10" />
          <text x={150} y={-84} fill={colors.inkDim} fontSize={28} fontWeight={600}>22 NM</text>
        </g>
      </svg>
    );
  }

  // climb: 200 ft/NM gradient
  const t = interpolate(frame, [10, fps * 3], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const px = interpolate(t, [0, 1], [150, 820]);
  const py = interpolate(t, [0, 1], [640, 300]);
  return (
    <svg width={960} height={780} viewBox="0 0 960 780">
      <line x1={60} y1={650} x2={900} y2={650} stroke={colors.inkDim} strokeWidth={4} />
      <rect x={90} y={642} width={120} height={8} fill={colors.ink} />
      {/* gradient line */}
      <line x1={150} y1={640} x2={860} y2={280} stroke={colors.green} strokeWidth={6} strokeDasharray="16 10" />
      {/* NM ticks */}
      {[1, 2, 3].map((nm) => (
        <g key={nm}>
          <line x1={150 + nm * 220} y1={650} x2={150 + nm * 220} y2={666} stroke={colors.inkDim} strokeWidth={3} />
          <text x={150 + nm * 220} y={706} fill={colors.inkDim} fontSize={28} fontWeight={600} textAnchor="middle">
            {nm} NM
          </text>
        </g>
      ))}
      <text x={430} y={250} fill={colors.green} fontSize={44} fontWeight={800}>
        200 ft / NM
      </text>
      <text x={430} y={302} fill={colors.inkDim} fontSize={30} fontWeight={600}>
        (a gradient, not a rate)
      </text>
      <g transform={`translate(${px}, ${py}) rotate(-26)`}>
        <path d="M 40 0 L -20 -12 L -11 0 L -20 12 Z" fill={colors.ink} />
      </g>
      <text x={110} y={600} fill={colors.inkDim} fontSize={26} fontWeight={600}>
        cross the end at 35 ft
      </text>
    </svg>
  );
};
