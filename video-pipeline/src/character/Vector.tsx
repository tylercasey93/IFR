import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import type { DukeExpression, DukePose } from '../types';

// Vector: the air traffic controller. Big over-ear headset worn ON with a
// boom mic to the mouth, dark facility polo, lanyard badge, energy of a man
// who has watched ten thousand pilots blow the same hold. Same rig API.

type Props = {
  pose?: DukePose;
  expression?: DukeExpression;
  talking?: boolean;
  size?: number;
};

const SKIN = '#B97F55';
const HAIR = '#14110E';
const POLO = '#232B26';
const POLO_SHADE = '#1A211D';
const SCOPE = '#39D98A';

export const Vector: React.FC<Props> = ({
  pose = 'stand',
  expression = 'neutral',
  talking = false,
  size = 560,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bob = Math.sin((frame / fps) * 2 * Math.PI * 0.35) * 3;
  const sway = Math.sin((frame / fps) * 2 * Math.PI * 0.16) * 1;
  const blinkPhase = frame % Math.round(fps * 3.4);
  const eyeOpen = blinkPhase < 4 ? 0.12 : 1;
  const flap = talking
    ? Math.abs(Math.sin(frame * 0.5)) * (0.35 + 0.65 * Math.abs(Math.sin(frame * 0.21 + 1.7)))
    : 0;
  const mouthH = 3 + flap * 13;
  const enter = spring({ frame, fps, config: { damping: 12, stiffness: 240 } });
  const sweep = ((frame / fps) * 90) % 360; // radar sweep on the badge

  const browLift = expression === 'eyebrowRaise' ? -9 : expression === 'squint' ? 5 : 0;
  const eyeH = (expression === 'squint' || expression === 'deadpan' ? 6 : 10) * eyeOpen;
  const smile = expression === 'grin' ? 9 : expression === 'deadpan' ? -2 : 1;

  return (
    <svg width={size * 0.78} height={size} viewBox="0 0 420 540" style={{ overflow: 'visible' }}>
      <g transform={`translate(${sway}, ${bob})`}>
        {/* facility polo */}
        <path d="M 96 540 L 96 402 Q 96 332 160 318 L 260 318 Q 324 332 324 402 L 324 540 Z" fill={POLO} />
        <path d="M 178 320 L 210 320 L 242 320 L 226 366 L 210 378 L 194 366 Z" fill={POLO_SHADE} />
        {/* lanyard + radar badge */}
        <path d="M 186 322 L 204 420 M 234 322 L 216 420" stroke="#7A2B22" strokeWidth={6} fill="none" />
        <g transform="translate(210, 436)">
          <rect x={-24} y={-18} width={48} height={58} rx={6} fill="#10140F" stroke={colors.aluminumDim} strokeWidth={2.5} />
          <circle cx={0} cy={6} r={16} fill="#06130C" stroke={SCOPE} strokeWidth={1.5} />
          <line
            x1={0}
            y1={6}
            x2={16 * Math.cos(((sweep - 90) * Math.PI) / 180)}
            y2={6 + 16 * Math.sin(((sweep - 90) * Math.PI) / 180)}
            stroke={SCOPE}
            strokeWidth={2}
          />
          <circle cx={6} cy={0} r={1.8} fill={SCOPE} />
          <circle cx={-7} cy={10} r={1.8} fill={SCOPE} />
        </g>

        <Arms pose={pose} enter={enter} frame={frame} />

        {/* head */}
        <g transform={`translate(0, ${talking ? Math.sin(frame * 0.32) * 1.2 : 0})`}>
          <rect x={192} y={288} width={36} height={40} rx={10} fill="#A26C47" />
          <path
            d="M 152 190 Q 150 130 210 126 Q 270 130 268 190 Q 270 254 240 282 Q 210 296 180 282 Q 150 254 152 190 Z"
            fill={SKIN}
          />
          {/* short flat-top hair */}
          <path d="M 154 168 Q 152 128 210 122 Q 268 128 266 168 Q 236 150 210 150 Q 184 150 154 168 Z" fill={HAIR} />
          {/* over-ear headset: band + big cups + boom mic to the mouth */}
          <path d="M 154 150 Q 210 106 266 150" stroke="#0E1420" strokeWidth={12} fill="none" strokeLinecap="round" />
          <ellipse cx={152} cy={206} rx={16} ry={24} fill="#0E1420" stroke={colors.bronze} strokeWidth={2.5} />
          <ellipse cx={268} cy={206} rx={16} ry={24} fill="#0E1420" stroke={colors.bronze} strokeWidth={2.5} />
          <path d="M 152 226 Q 156 262 188 268" stroke="#0E1420" strokeWidth={6} fill="none" />
          <ellipse cx={193} cy={269} rx={8} ry={6} fill="#0E1420" />
          {/* tired-but-sharp eyes */}
          <g transform={`translate(0, ${browLift})`}>
            <path d="M 168 186 Q 184 179 198 185" stroke={HAIR} strokeWidth={7} fill="none" strokeLinecap="round" />
            <path
              d={expression === 'eyebrowRaise' ? 'M 222 182 Q 236 171 252 181' : 'M 222 185 Q 236 178 252 184'}
              stroke={HAIR}
              strokeWidth={7}
              fill="none"
              strokeLinecap="round"
            />
          </g>
          <ellipse cx={184} cy={204} rx={9} ry={eyeH} fill="#26302B" />
          <ellipse cx={236} cy={204} rx={9} ry={eyeH} fill="#26302B" />
          <path d="M 172 218 L 180 217 M 248 218 L 240 217" stroke="#A26C47" strokeWidth={2.5} strokeLinecap="round" />
          <path d="M 208 206 Q 203 228 210 236 Q 215 232 213 226" fill="none" stroke="#A26C47" strokeWidth={4} strokeLinecap="round" />
          {/* mouth (next to the boom mic) */}
          <g transform="translate(212, 258)">
            <ellipse cx={0} cy={mouthH / 2} rx={14 + flap * 4} ry={mouthH} fill="#3A2A26" />
            {!talking && (
              <path d={`M -16 0 Q 0 ${smile} 16 0`} stroke="#3A2A26" strokeWidth={4} fill="none" strokeLinecap="round" />
            )}
          </g>
        </g>
      </g>
    </svg>
  );
};

const Arms: React.FC<{ pose: DukePose; enter: number; frame: number }> = ({ pose, enter, frame }) => {
  const steam = Math.sin(frame * 0.09);

  if (pose === 'point') {
    const reach = interpolate(enter, [0, 1], [40, 0]);
    return (
      <g>
        <path d="M 306 358 Q 336 402 330 452" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
        <Mug x={318} y={468} steam={steam} />
        <g transform={`translate(${reach}, ${-reach * 0.4}) rotate(${(1 - enter) * 14}, 120, 380)`}>
          <path d="M 116 358 Q 60 358 24 330" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
          <circle cx={20} cy={326} r={15} fill={SKIN} />
          <rect x={-14} y={318} width={34} height={13} rx={6.5} fill={SKIN} />
        </g>
      </g>
    );
  }

  if (pose === 'coffeeSip') {
    const lift = interpolate(enter, [0, 1], [70, 0]);
    return (
      <g>
        <path d="M 114 358 Q 86 402 92 452" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
        <circle cx={92} cy={466} r={16} fill={SKIN} />
        <g transform={`translate(0, ${lift})`}>
          <path d="M 306 358 Q 330 342 296 302" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
          <Mug x={282} y={288} steam={steam} />
        </g>
      </g>
    );
  }

  if (pose === 'armsCrossed') {
    return (
      <g>
        <path d="M 116 362 Q 150 410 232 402" stroke={POLO_SHADE} strokeWidth={34} fill="none" strokeLinecap="round" />
        <path d="M 304 362 Q 270 414 190 404" stroke={POLO} strokeWidth={34} fill="none" strokeLinecap="round" />
        <circle cx={236} cy={402} r={15} fill={SKIN} />
        <circle cx={186} cy={404} r={15} fill={SKIN} />
      </g>
    );
  }

  return (
    <g>
      <path d="M 114 358 Q 88 402 94 456" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
      <circle cx={94} cy={470} r={16} fill={SKIN} />
      <path d="M 306 358 Q 334 402 328 452" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
      <Mug x={316} y={468} steam={steam} />
    </g>
  );
};

// The controller's giant thermos mug.
const Mug: React.FC<{ x: number; y: number; steam: number }> = ({ x, y, steam }) => (
  <g transform={`translate(${x}, ${y})`}>
    <circle cx={0} cy={-16} r={16} fill={SKIN} />
    <rect x={-17} y={-10} width={34} height={54} rx={7} fill="#4A5450" />
    <rect x={-17} y={-10} width={34} height={10} rx={5} fill="#2B3330" />
    <path d="M 17 4 Q 34 10 17 28" stroke="#4A5450" strokeWidth={7} fill="none" />
    <g opacity={0.4} stroke="#FFFFFF" strokeWidth={3.5} fill="none" strokeLinecap="round">
      <path d={`M -4 -16 Q ${-8 + steam * 4} -30 -4 -42`} />
    </g>
  </g>
);
