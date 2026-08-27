import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';

// Timeline teaching graphics.
//  variant="eta-window": the 1-2-3 alternate rule window around ETA
//  variant="currency":   the 6 / 6-12 / 12+ month IFR currency bands

type Props = { variant?: 'eta-window' | 'currency' };

export const Timeline: React.FC<Props> = ({ variant = 'eta-window' }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  if (variant === 'currency') {
    const bands = [
      { label: 'CURRENT', sub: '6-6-HIT', color: colors.green, x: 80, w: 280 },
      { label: 'GRACE', sub: 'regain it yourself', color: colors.amber, x: 360, w: 280 },
      { label: 'IPC', sub: 'see an instructor', color: colors.red, x: 640, w: 240 },
    ];
    const marker = interpolate(frame, [12, fps * 3.6], [90, 860], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    return (
      <svg width={960} height={780} viewBox="0 0 960 780">
        {bands.map((b, i) => {
          const bandIn = spring({ frame: frame - 6 - i * 8, fps, config: { damping: 14, stiffness: 130 } });
          return (
            <g key={b.label} opacity={bandIn}>
              <rect x={b.x} y={330} width={b.w} height={120} rx={18} fill={b.color} opacity={0.28} />
              <rect x={b.x} y={330} width={b.w} height={120} rx={18} fill="none" stroke={b.color} strokeWidth={4} />
              <text x={b.x + b.w / 2} y={382} fill={b.color} fontSize={40} fontWeight={800} textAnchor="middle">
                {b.label}
              </text>
              <text x={b.x + b.w / 2} y={428} fill={colors.inkDim} fontSize={26} fontWeight={600} textAnchor="middle">
                {b.sub}
              </text>
            </g>
          );
        })}
        {[0, 6, 12].map((m, i) => (
          <text key={m} x={[80, 360, 640][i]} y={510} fill={colors.inkDim} fontSize={30} fontWeight={700}>
            {m} mo
          </text>
        ))}
        {/* today marker sliding right as months pass */}
        <g transform={`translate(${marker}, 0)`}>
          <line x1={0} y1={280} x2={0} y2={470} stroke={colors.ink} strokeWidth={5} />
          <path d="M 0 268 L 14 244 L -14 244 Z" fill={colors.ink} />
          <text y={230} fill={colors.ink} fontSize={28} fontWeight={700} textAnchor="middle">
            time flies
          </text>
        </g>
      </svg>
    );
  }

  // eta-window: ±1 hour band around ETA with the 2,000 / 3 chips
  const bandIn = spring({ frame: frame - 8, fps, config: { damping: 14, stiffness: 120 } });
  const chips = ['≥ 2,000 ft ceiling', '≥ 3 SM visibility'];
  return (
    <svg width={960} height={780} viewBox="0 0 960 780">
      <line x1={80} y1={430} x2={880} y2={430} stroke={colors.inkDim} strokeWidth={5} />
      {['-2 hr', '-1 hr', 'ETA', '+1 hr', '+2 hr'].map((label, i) => {
        const x = 130 + i * 175;
        const isEta = label === 'ETA';
        return (
          <g key={label}>
            <line x1={x} y1={415} x2={x} y2={445} stroke={isEta ? colors.amber : colors.inkDim} strokeWidth={isEta ? 6 : 3} />
            <text x={x} y={496} fill={isEta ? colors.amber : colors.inkDim} fontSize={isEta ? 38 : 28} fontWeight={isEta ? 800 : 600} textAnchor="middle">
              {label}
            </text>
          </g>
        );
      })}
      {/* the ±1 hour window */}
      <rect
        x={305}
        y={360}
        width={350 * bandIn}
        height={140}
        rx={20}
        fill={colors.green}
        opacity={0.2}
      />
      <rect x={305} y={360} width={350 * bandIn} height={140} rx={20} fill="none" stroke={colors.green} strokeWidth={5} />
      <text x={480} y={330} fill={colors.green} fontSize={38} fontWeight={800} textAnchor="middle" opacity={bandIn}>
        forecast must hold, the whole window
      </text>
      {chips.map((chip, i) => {
        const chipIn = spring({ frame: frame - 30 - i * 12, fps, config: { damping: 13, stiffness: 140 } });
        return (
          <g key={chip} opacity={chipIn} transform={`translate(0, ${(1 - chipIn) * 30})`}>
            <rect x={280} y={560 + i * 90} width={400} height={72} rx={16} fill={colors.panel} stroke={colors.green} strokeWidth={3.5} />
            <text x={480} y={608 + i * 90} fill={colors.ink} fontSize={36} fontWeight={700} textAnchor="middle">
              {chip}
            </text>
          </g>
        );
      })}
    </svg>
  );
};
