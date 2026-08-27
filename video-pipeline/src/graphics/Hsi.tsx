import React from 'react';
import { interpolate, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';

// VOR/CDI/HSI teaching graphic.
//  stage="radials": a VOR station with radial spokes (radials point FROM).
//  stage="cdi":     a classic CDI face with a deflecting needle.
//  stage="hsi":     an HSI with rotating heading card + course arrow.

type Props = { stage?: 'radials' | 'cdi' | 'hsi' };

export const Hsi: React.FC<Props> = ({ stage = 'hsi' }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;

  if (stage === 'radials') {
    const grow = interpolate(frame, [5, 40], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        {Array.from({ length: 12 }, (_, i) => {
          const deg = i * 30;
          const rad = ((deg - 90) * Math.PI) / 180;
          const len = 300 * grow;
          return (
            <g key={i}>
              <line
                x1={480}
                y1={390}
                x2={480 + Math.cos(rad) * len}
                y2={390 + Math.sin(rad) * len}
                stroke={deg === 90 ? colors.green : colors.inkDim}
                strokeWidth={deg === 90 ? 8 : 3}
              />
              <text
                x={480 + Math.cos(rad) * 340}
                y={390 + Math.sin(rad) * 340 + 10}
                fill={deg === 90 ? colors.green : colors.inkDim}
                fontSize={30}
                fontWeight={700}
                textAnchor="middle"
                opacity={grow}
              >
                {String(deg === 0 ? 360 : deg).padStart(3, '0')}
              </text>
            </g>
          );
        })}
        {/* VOR station symbol */}
        <path d="M 480 356 L 510 373 L 510 407 L 480 424 L 450 407 L 450 373 Z" fill={colors.panel} stroke={colors.ink} strokeWidth={5} />
        <circle cx={480} cy={390} r={7} fill={colors.ink} />
        <text x={480} y={470} fill={colors.ink} fontSize={30} fontWeight={700} textAnchor="middle" opacity={grow}>
          VOR
        </text>
        <text x={790} y={350} fill={colors.green} fontSize={32} fontWeight={800} opacity={grow}>
          090 radial →
        </text>
      </svg>
    );
  }

  if (stage === 'cdi') {
    // Needle drifts toward center as "the pilot corrects".
    const deflect = interpolate(frame, [10, fps * 3.5], [95, 8], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        <circle cx={480} cy={390} r={280} fill="#10140F" stroke={colors.panelEdge} strokeWidth={6} />
        {/* deflection dots */}
        {[-2, -1, 1, 2].map((i) => (
          <circle key={i} cx={480 + i * 60} cy={390} r={9} fill="none" stroke={colors.inkDim} strokeWidth={3} />
        ))}
        <circle cx={480} cy={390} r={12} fill="none" stroke={colors.ink} strokeWidth={4} />
        {/* course needle */}
        <line x1={480 + deflect} y1={160} x2={480 + deflect} y2={620} stroke={colors.green} strokeWidth={12} strokeLinecap="round" />
        {/* OBS course at top */}
        <g transform="translate(480, 128)">
          <path d="M 0 -26 L 20 8 L -20 8 Z" fill={colors.amber} />
          <text y={-40} fill={colors.amber} fontSize={34} fontWeight={800} textAnchor="middle">
            OBS 090
          </text>
        </g>
        {/* TO flag */}
        <path d="M 560 300 L 588 340 L 532 340 Z" fill={colors.ink} />
        <text x={560} y={378} fill={colors.inkDim} fontSize={26} fontWeight={600} textAnchor="middle">TO</text>
        <text x={480} y={720} fill={colors.green} fontSize={34} fontWeight={800} textAnchor="middle">
          course is to your {deflect > 20 ? 'right — fly right' : 'nose — hold it'}
        </text>
      </svg>
    );
  }

  // HSI: heading card swings gently; course arrow + deviation bar ride the card.
  const heading = 90 + Math.sin(t * 0.7) * 14;
  const dev = Math.sin(t * 0.9) * 26;
  return (
    <svg width={960} height={780} viewBox="0 0 960 780">
      <circle cx={480} cy={390} r={300} fill="#10140F" stroke={colors.panelEdge} strokeWidth={6} />
      <g transform={`rotate(${-heading}, 480, 390)`}>
        {/* compass card */}
        {Array.from({ length: 36 }, (_, i) => {
          const deg = i * 10;
          const rad = ((deg - 90) * Math.PI) / 180;
          const inner = deg % 30 === 0 ? 252 : 268;
          return (
            <line
              key={i}
              x1={480 + Math.cos(rad) * inner}
              y1={390 + Math.sin(rad) * inner}
              x2={480 + Math.cos(rad) * 286}
              y2={390 + Math.sin(rad) * 286}
              stroke={colors.inkDim}
              strokeWidth={deg % 30 === 0 ? 5 : 2.5}
            />
          );
        })}
        {['N', '3', '6', 'E', '12', '15', 'S', '21', '24', 'W', '30', '33'].map((label, i) => {
          const rad = ((i * 30 - 90) * Math.PI) / 180;
          return (
            <text
              key={label}
              x={480 + Math.cos(rad) * 222}
              y={390 + Math.sin(rad) * 222 + 12}
              fill={colors.ink}
              fontSize={36}
              fontWeight={700}
              textAnchor="middle"
              transform={`rotate(${i * 30}, ${480 + Math.cos(rad) * 222}, ${390 + Math.sin(rad) * 222})`}
            >
              {label}
            </text>
          );
        })}
        {/* course arrow (set to 090) rotates with the card */}
        <g transform="rotate(90, 480, 390)">
          <line x1={480} y1={190} x2={480} y2={330} stroke={colors.green} strokeWidth={11} />
          <path d="M 480 165 L 500 205 L 460 205 Z" fill={colors.green} />
          <line x1={480} y1={450} x2={480} y2={590} stroke={colors.green} strokeWidth={11} />
          {/* deviation bar */}
          <line x1={480 + dev} y1={340} x2={480 + dev} y2={440} stroke={colors.green} strokeWidth={11} />
        </g>
      </g>
      {/* fixed airplane symbol + lubber line */}
      <line x1={480} y1={78} x2={480} y2={116} stroke={colors.amber} strokeWidth={8} />
      <g stroke={colors.ink} strokeWidth={8} strokeLinecap="round">
        <line x1={480} y1={356} x2={480} y2={424} />
        <line x1={444} y1={384} x2={516} y2={384} />
        <line x1={462} y1={418} x2={498} y2={418} />
      </g>
      <text x={480} y={740} fill={colors.green} fontSize={34} fontWeight={800} textAnchor="middle">
        card turns with you — the picture always matches
      </text>
    </svg>
  );
};
