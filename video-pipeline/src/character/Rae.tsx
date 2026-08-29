import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import type { DukeExpression, DukePose } from '../types';

// Captain Rae: mid-career airline captain. Captain's hat with gold braid,
// sleek dark bob, navy uniform jacket with four gold stripes, white shirt
// and tie, coffee (tradition). Same rig API as Duke.

type Props = {
  pose?: DukePose;
  expression?: DukeExpression;
  talking?: boolean;
  size?: number;
};

const SKIN = '#C68863';
const HAIR = '#1E1A17';
const JACKET = '#1B2438';
const JACKET_SHADE = '#141B2B';
const GOLD = '#C9A24B';
const SHIRT = '#F2F5F3';

export const Rae: React.FC<Props> = ({
  pose = 'stand',
  expression = 'neutral',
  talking = false,
  size = 560,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bob = Math.sin((frame / fps) * 2 * Math.PI * 0.4) * 3.5;
  const sway = Math.sin((frame / fps) * 2 * Math.PI * 0.18) * 1;
  const blinkPhase = frame % Math.round(fps * 3.1);
  const eyeOpen = blinkPhase < 4 ? 0.12 : 1;
  const flap = talking
    ? Math.abs(Math.sin(frame * 0.52)) * (0.35 + 0.65 * Math.abs(Math.sin(frame * 0.22 + 0.8)))
    : 0;
  const mouthH = 3 + flap * 14;
  const enter = spring({ frame, fps, config: { damping: 12, stiffness: 240 } });

  const browLift = expression === 'eyebrowRaise' ? -9 : expression === 'squint' ? 4 : 0;
  const eyeH = (expression === 'squint' || expression === 'deadpan' ? 7 : 11) * eyeOpen;
  const smile = expression === 'grin' ? 10 : expression === 'deadpan' ? 0 : 3;

  return (
    <svg width={size * 0.78} height={size} viewBox="0 0 420 540" style={{ overflow: 'visible' }}>
      <g transform={`translate(${sway}, ${bob})`}>
        {/* uniform jacket */}
        <path d="M 98 540 L 98 402 Q 98 332 162 318 L 258 318 Q 322 332 322 402 L 322 540 Z" fill={JACKET} />
        {/* lapels + shirt + tie */}
        <path d="M 176 320 L 210 320 L 244 320 L 226 380 L 210 396 L 194 380 Z" fill={SHIRT} />
        <path d="M 176 320 L 194 380 L 182 392 Q 160 352 176 320 Z" fill={JACKET_SHADE} />
        <path d="M 244 320 L 226 380 L 238 392 Q 260 352 244 320 Z" fill={JACKET_SHADE} />
        <path d="M 206 330 L 214 330 L 218 372 L 210 388 L 202 372 Z" fill="#7A2B22" />
        {/* four captain stripes on each sleeve cuff */}
        {[0, 1, 2, 3].map((i) => (
          <g key={i}>
            <rect x={100} y={470 + i * 12} width={44} height={6} fill={GOLD} transform="rotate(8, 122, 473)" />
            <rect x={276} y={470 + i * 12} width={44} height={6} fill={GOLD} transform="rotate(-8, 298, 473)" />
          </g>
        ))}
        {/* wings pin */}
        <g transform="translate(262, 350)">
          <path d="M -12 2 L 0 -6 L 12 2 L 0 -1 Z" fill={GOLD} />
        </g>

        <Arms pose={pose} enter={enter} frame={frame} />

        {/* head */}
        <g transform={`translate(0, ${talking ? Math.sin(frame * 0.3) * 1.1 : 0})`}>
          <rect x={192} y={288} width={36} height={42} rx={10} fill="#B0764F" />
          {/* bob behind the face */}
          <path d="M 146 200 Q 138 122 210 116 Q 282 122 274 200 Q 282 268 258 288 L 244 268 Q 258 220 250 180 L 170 180 Q 162 220 176 268 L 162 288 Q 138 268 146 200 Z" fill={HAIR} />
          <path
            d="M 154 192 Q 152 136 210 132 Q 268 136 266 192 Q 268 252 238 280 Q 210 294 182 280 Q 152 252 154 192 Z"
            fill={SKIN}
          />
          {/* bob framing the face */}
          <path d="M 154 196 Q 148 148 176 136 Q 160 176 164 232 Q 156 216 154 196 Z" fill={HAIR} />
          <path d="M 266 196 Q 272 148 244 136 Q 260 176 256 232 Q 264 216 266 196 Z" fill={HAIR} />
          {/* captain's hat */}
          <path d="M 150 148 Q 154 104 210 100 Q 266 104 270 148 L 264 152 Q 210 132 156 152 Z" fill={JACKET} />
          <path d="M 148 150 Q 210 128 272 150 L 272 162 Q 210 142 148 162 Z" fill="#0E1420" />
          <path d="M 186 152 Q 210 146 234 152" stroke={GOLD} strokeWidth={4} fill="none" />
          <circle cx={210} cy={122} r={9} fill={GOLD} />
          {/* brows */}
          <g transform={`translate(0, ${browLift})`}>
            <path d="M 170 188 Q 184 181 198 187" stroke={HAIR} strokeWidth={6} fill="none" strokeLinecap="round" />
            <path
              d={expression === 'eyebrowRaise' ? 'M 222 184 Q 236 173 250 182' : 'M 222 187 Q 236 180 250 186'}
              stroke={HAIR}
              strokeWidth={6}
              fill="none"
              strokeLinecap="round"
            />
          </g>
          <ellipse cx={185} cy={204} rx={8.5} ry={eyeH} fill="#26302B" />
          <ellipse cx={235} cy={204} rx={8.5} ry={eyeH} fill="#26302B" />
          <path d="M 208 206 Q 204 226 210 234 Q 215 230 213 224" fill="none" stroke="#B0764F" strokeWidth={3.5} strokeLinecap="round" />
          <g transform="translate(210, 256)">
            <ellipse cx={0} cy={mouthH / 2} rx={14 + flap * 4} ry={mouthH} fill="#5A2E28" />
            {!talking && (
              <path d={`M -16 0 Q 0 ${smile} 16 0`} stroke="#5A2E28" strokeWidth={4} fill="none" strokeLinecap="round" />
            )}
          </g>
        </g>
      </g>
    </svg>
  );
};

const Arms: React.FC<{ pose: DukePose; enter: number; frame: number }> = ({ pose, enter, frame }) => {
  const steam = Math.sin(frame * 0.1);

  if (pose === 'point') {
    const reach = interpolate(enter, [0, 1], [40, 0]);
    return (
      <g>
        <path d="M 304 358 Q 334 402 328 452" stroke={JACKET_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
        <Cup x={316} y={468} steam={steam} />
        <g transform={`translate(${reach}, ${-reach * 0.4}) rotate(${(1 - enter) * 14}, 120, 380)`}>
          <path d="M 118 358 Q 62 358 26 330" stroke={JACKET_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
          <circle cx={22} cy={326} r={14} fill={SKIN} />
          <rect x={-12} y={319} width={34} height={12} rx={6} fill={SKIN} />
        </g>
      </g>
    );
  }

  if (pose === 'coffeeSip') {
    const lift = interpolate(enter, [0, 1], [70, 0]);
    return (
      <g>
        <path d="M 116 358 Q 88 402 94 452" stroke={JACKET_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
        <circle cx={94} cy={466} r={15} fill={SKIN} />
        <g transform={`translate(0, ${lift})`}>
          <path d="M 304 358 Q 328 342 294 302" stroke={JACKET_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
          <Cup x={280} y={288} steam={steam} />
        </g>
      </g>
    );
  }

  if (pose === 'armsCrossed') {
    return (
      <g>
        <path d="M 118 362 Q 152 410 232 402" stroke={JACKET_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
        <path d="M 302 362 Q 268 414 190 404" stroke={JACKET} strokeWidth={32} fill="none" strokeLinecap="round" />
        <circle cx={236} cy={402} r={14} fill={SKIN} />
        <circle cx={186} cy={404} r={14} fill={SKIN} />
      </g>
    );
  }

  return (
    <g>
      <path d="M 116 358 Q 90 402 96 456" stroke={JACKET_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
      <circle cx={96} cy={470} r={15} fill={SKIN} />
      <path d="M 304 358 Q 332 402 326 452" stroke={JACKET_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
      <Cup x={314} y={468} steam={steam} />
    </g>
  );
};

const Cup: React.FC<{ x: number; y: number; steam: number }> = ({ x, y, steam }) => (
  <g transform={`translate(${x}, ${y})`}>
    <circle cx={0} cy={-13} r={15} fill={SKIN} />
    <path d="M -16 -6 L 16 -6 L 12 34 L -12 34 Z" fill="#F2F5F3" />
    <rect x={-16} y={0} width={32} height={7} fill={colors.bronze} />
    <g opacity={0.5} stroke="#FFFFFF" strokeWidth={3.5} fill="none" strokeLinecap="round">
      <path d={`M -4 -12 Q ${-8 + steam * 4} -26 -4 -38`} />
      <path d={`M 6 -12 Q ${10 - steam * 4} -28 6 -42`} opacity={0.7} />
    </g>
  </g>
);
