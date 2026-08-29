import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import type { DukeExpression, DukePose } from '../types';

// Dr. Ceil Novak: aerospace nerd — engineer-turned-examiner who is DELIGHTED
// by the system. Round glasses, enthusiastic messy hair, button-up with tie
// and a pocket protector full of pens, slide rule in hand. Same rig API.

type Props = {
  pose?: DukePose;
  expression?: DukeExpression;
  talking?: boolean;
  size?: number;
};

const SKIN = '#E8C29A';
const HAIR = '#4A3B2A';
const SHIRT = '#DCE4E8';
const SHIRT_SHADE = '#C2CCD2';
const TIE = '#6B3FA0';
const RULE = '#D8C9A3';

export const Novak: React.FC<Props> = ({
  pose = 'stand',
  expression = 'neutral',
  talking = false,
  size = 560,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bob = Math.sin((frame / fps) * 2 * Math.PI * 0.65) * 5;
  const sway = Math.sin((frame / fps) * 2 * Math.PI * 0.3) * 1.6;
  const blinkPhase = frame % Math.round(fps * 2.2);
  const eyeOpen = blinkPhase < 4 ? 0.15 : 1;
  const flap = talking
    ? Math.abs(Math.sin(frame * 0.62)) * (0.4 + 0.6 * Math.abs(Math.sin(frame * 0.29 + 0.4)))
    : 0;
  const mouthH = 3 + flap * 16;
  const enter = spring({ frame, fps, config: { damping: 11, stiffness: 250 } });

  const browLift = expression === 'eyebrowRaise' ? -12 : expression === 'squint' ? 3 : -3; // resting enthusiasm
  const eyeH = (expression === 'squint' || expression === 'deadpan' ? 7 : 12) * eyeOpen;
  const smile = expression === 'deadpan' ? 1 : 8; // he's basically always smiling

  return (
    <svg width={size * 0.78} height={size} viewBox="0 0 420 540" style={{ overflow: 'visible' }}>
      <g transform={`translate(${sway}, ${bob})`}>
        {/* shirt + tie */}
        <path d="M 98 540 L 98 402 Q 98 332 162 318 L 258 318 Q 322 332 322 402 L 322 540 Z" fill={SHIRT} />
        <path d="M 178 320 L 210 320 L 242 320 L 228 368 L 210 382 L 192 368 Z" fill="#FFFFFF" />
        <path d="M 204 330 L 216 330 L 222 400 L 210 428 L 198 400 Z" fill={TIE} />
        {/* pocket protector with pens */}
        <g transform="translate(146, 380)">
          <rect x={0} y={0} width={44} height={52} rx={4} fill="#FFFFFF" stroke={SHIRT_SHADE} strokeWidth={2} />
          <rect x={7} y={-14} width={7} height={26} rx={3} fill={colors.red} />
          <rect x={18} y={-18} width={7} height={30} rx={3} fill="#2B5AA6" />
          <rect x={29} y={-12} width={7} height={24} rx={3} fill="#26302B" />
        </g>

        <Arms pose={pose} enter={enter} frame={frame} />

        {/* head */}
        <g transform={`translate(0, ${talking ? Math.sin(frame * 0.4) * 1.6 : 0})`}>
          <rect x={192} y={288} width={36} height={40} rx={10} fill="#D3A87E" />
          <path
            d="M 152 190 Q 150 130 210 126 Q 270 130 268 190 Q 270 254 240 282 Q 210 296 180 282 Q 150 254 152 190 Z"
            fill={SKIN}
          />
          {/* enthusiastic messy hair */}
          <path
            d="M 150 176 Q 142 148 160 132 Q 158 116 178 118 Q 184 102 206 110 Q 220 98 236 112 Q 258 104 262 126 Q 280 130 272 156 Q 280 168 270 180 Q 240 150 210 152 Q 178 152 150 176 Z"
            fill={HAIR}
          />
          {/* round glasses */}
          <g stroke="#3B3630" strokeWidth={4} fill="rgba(255,255,255,0.06)">
            <circle cx={184} cy={204} r={20} />
            <circle cx={236} cy={204} r={20} />
            <path d="M 204 204 L 216 204" fill="none" />
            <path d="M 164 202 L 154 196 M 256 202 L 266 196" fill="none" />
          </g>
          {/* brows */}
          <g transform={`translate(0, ${browLift})`}>
            <path d="M 166 182 Q 184 172 200 180" stroke={HAIR} strokeWidth={7} fill="none" strokeLinecap="round" />
            <path d="M 220 180 Q 236 170 254 180" stroke={HAIR} strokeWidth={7} fill="none" strokeLinecap="round" />
          </g>
          {/* wide bright eyes behind the lenses */}
          <ellipse cx={184} cy={204} rx={7.5} ry={eyeH} fill="#26302B" />
          <ellipse cx={236} cy={204} rx={7.5} ry={eyeH} fill="#26302B" />
          <circle cx={187} cy={200} r={2} fill="#FFFFFF" opacity={eyeOpen} />
          <circle cx={239} cy={200} r={2} fill="#FFFFFF" opacity={eyeOpen} />
          <path d="M 208 208 Q 204 228 211 236 Q 216 232 214 226" fill="none" stroke="#D3A87E" strokeWidth={4} strokeLinecap="round" />
          {/* mouth */}
          <g transform="translate(210, 258)">
            <ellipse cx={0} cy={mouthH / 2} rx={15 + flap * 5} ry={mouthH} fill="#5A2E28" />
            {!talking && (
              <path d={`M -17 0 Q 0 ${smile} 17 0`} stroke="#5A2E28" strokeWidth={4} fill="none" strokeLinecap="round" />
            )}
          </g>
        </g>
      </g>
    </svg>
  );
};

const Arms: React.FC<{ pose: DukePose; enter: number; frame: number }> = ({ pose, enter, frame }) => {
  const wiggle = Math.sin(frame * 0.2) * 3;

  if (pose === 'point') {
    const reach = interpolate(enter, [0, 1], [40, 0]);
    return (
      <g>
        <path d="M 304 358 Q 334 402 328 452" stroke={SHIRT_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
        <SlideRule x={314} y={462} wiggle={0} />
        <g transform={`translate(${reach}, ${-reach * 0.4}) rotate(${(1 - enter) * 16}, 120, 380)`}>
          <path d="M 118 358 Q 62 358 26 330" stroke={SHIRT_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
          <circle cx={22} cy={326} r={14} fill={SKIN} />
          <rect x={-12} y={319} width={34} height={12} rx={6} fill={SKIN} />
        </g>
      </g>
    );
  }

  if (pose === 'coffeeSip') {
    // Novak doesn't sip — he consults the slide rule up close, gleefully.
    const lift = interpolate(enter, [0, 1], [70, 0]);
    return (
      <g>
        <path d="M 116 358 Q 88 402 94 452" stroke={SHIRT_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
        <circle cx={94} cy={466} r={15} fill={SKIN} />
        <g transform={`translate(0, ${lift})`}>
          <path d="M 304 358 Q 328 342 294 302" stroke={SHIRT_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
          <SlideRule x={276} y={288} wiggle={wiggle} />
        </g>
      </g>
    );
  }

  if (pose === 'armsCrossed') {
    return (
      <g>
        <path d="M 118 362 Q 152 410 232 402" stroke={SHIRT_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
        <path d="M 302 362 Q 268 414 190 404" stroke={SHIRT} strokeWidth={32} fill="none" strokeLinecap="round" />
        <circle cx={236} cy={402} r={14} fill={SKIN} />
        <circle cx={186} cy={404} r={14} fill={SKIN} />
      </g>
    );
  }

  return (
    <g>
      <path d="M 116 358 Q 90 402 96 456" stroke={SHIRT_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
      <circle cx={96} cy={470} r={15} fill={SKIN} />
      <path d="M 304 358 Q 332 402 326 452" stroke={SHIRT_SHADE} strokeWidth={30} fill="none" strokeLinecap="round" />
      <SlideRule x={314} y={462} wiggle={0} />
    </g>
  );
};

const SlideRule: React.FC<{ x: number; y: number; wiggle: number }> = ({ x, y, wiggle }) => (
  <g transform={`translate(${x}, ${y}) rotate(${-24 + wiggle})`}>
    <circle cx={0} cy={-10} r={15} fill={SKIN} />
    <rect x={-44} y={-6} width={88} height={20} rx={3} fill={RULE} stroke="#8C7A55" strokeWidth={2} />
    <rect x={-14} y={-10} width={28} height={28} rx={2} fill="none" stroke="#8C7A55" strokeWidth={2.5} />
    <line x1={0} y1={-10} x2={0} y2={18} stroke={colors.red} strokeWidth={1.8} />
    {[-36, -28, -20, 20, 28, 36].map((tx) => (
      <line key={tx} x1={tx} y1={-2} x2={tx} y2={8} stroke="#8C7A55" strokeWidth={1.5} />
    ))}
  </g>
);
