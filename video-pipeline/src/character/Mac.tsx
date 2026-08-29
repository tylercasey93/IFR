import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import type { DukeExpression, DukePose } from '../types';

// Mac: sharp young CFI. Backwards cap, stubble, aviators on the collar,
// flight-school polo with epaulettes, headset around the neck, energy drink
// that never leaves his hand. Same rig API as Duke.

type Props = {
  pose?: DukePose;
  expression?: DukeExpression;
  talking?: boolean;
  size?: number;
};

const SKIN = '#D9A278';
const HAIR = '#2E2620';
const POLO = '#F2F0EA';
const POLO_SHADE = '#D8D4C8';
const CAP = '#243447';
const CAN = '#3EC6A8';

export const Mac: React.FC<Props> = ({
  pose = 'stand',
  expression = 'neutral',
  talking = false,
  size = 560,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bob = Math.sin((frame / fps) * 2 * Math.PI * 0.55) * 4.5;
  const sway = Math.sin((frame / fps) * 2 * Math.PI * 0.25) * 1.4;
  const blinkPhase = frame % Math.round(fps * 2.6);
  const eyeOpen = blinkPhase < 4 ? 0.12 : 1;
  const flap = talking
    ? Math.abs(Math.sin(frame * 0.6)) * (0.35 + 0.65 * Math.abs(Math.sin(frame * 0.27 + 1.1)))
    : 0;
  const mouthH = 3 + flap * 15;
  const enter = spring({ frame, fps, config: { damping: 12, stiffness: 240 } });

  const browLift = expression === 'eyebrowRaise' ? -10 : expression === 'squint' ? 4 : 0;
  const eyeH = (expression === 'squint' || expression === 'deadpan' ? 7 : 11) * eyeOpen;
  const smile = expression === 'grin' ? 11 : expression === 'deadpan' ? -1 : 3;

  return (
    <svg width={size * 0.78} height={size} viewBox="0 0 420 540" style={{ overflow: 'visible' }}>
      <g transform={`translate(${sway}, ${bob})`}>
        {/* polo torso with epaulettes */}
        <path d="M 96 540 L 96 400 Q 96 330 160 316 L 260 316 Q 324 330 324 400 L 324 540 Z" fill={POLO} />
        <path d="M 200 322 L 220 322 L 224 540 L 196 540 Z" fill={POLO_SHADE} />
        <path d="M 176 318 L 210 318 L 244 318 L 228 362 L 210 374 L 192 362 Z" fill={POLO_SHADE} />
        {/* epaulette boards */}
        <rect x={120} y={324} width={56} height={16} rx={6} fill={CAP} transform="rotate(-14, 148, 332)" />
        <rect x={244} y={324} width={56} height={16} rx={6} fill={CAP} transform="rotate(14, 272, 332)" />
        {/* aviators hooked on collar */}
        <g transform="translate(210, 372)">
          <path d="M -12 0 L 12 0" stroke="#B89A55" strokeWidth={3} />
          <ellipse cx={-9} cy={9} rx={9} ry={11} fill="#2B2F2C" stroke="#B89A55" strokeWidth={2.5} />
          <ellipse cx={9} cy={9} rx={9} ry={11} fill="#2B2F2C" stroke="#B89A55" strokeWidth={2.5} />
        </g>
        {/* headset around neck */}
        <path d="M 158 332 Q 210 372 262 332" stroke="#222623" strokeWidth={12} fill="none" strokeLinecap="round" />
        <circle cx={158} cy={332} r={18} fill="#222623" stroke={colors.bronze} strokeWidth={3} />
        <circle cx={262} cy={332} r={18} fill="#222623" stroke={colors.bronze} strokeWidth={3} />

        <Arms pose={pose} enter={enter} frame={frame} fps={fps} />

        {/* head */}
        <g transform={`translate(0, ${talking ? Math.sin(frame * 0.35) * 1.4 : 0})`}>
          <rect x={192} y={288} width={36} height={40} rx={10} fill="#C08B62" />
          <path
            d="M 150 188 Q 148 128 210 124 Q 272 128 270 188 Q 272 254 240 284 Q 210 298 180 284 Q 148 254 150 188 Z"
            fill={SKIN}
          />
          {/* stubble */}
          <path
            d="M 168 250 Q 210 288 252 250 Q 246 274 210 282 Q 174 274 168 250 Z"
            fill={HAIR}
            opacity={0.22}
          />
          {/* hair peeking under the cap */}
          <path d="M 150 190 Q 148 168 158 152 L 158 196 Q 152 196 150 190 Z" fill={HAIR} />
          <path d="M 270 190 Q 272 168 262 152 L 262 196 Q 268 196 270 190 Z" fill={HAIR} />
          {/* backwards cap: dome + strap gap + rear brim pointing back-left */}
          <path d="M 150 160 Q 152 116 210 112 Q 268 116 270 160 L 264 166 Q 210 144 156 166 Z" fill={CAP} />
          <path d="M 152 158 L 108 148 Q 100 156 106 164 L 150 168 Z" fill={CAP} />
          <rect x={196} y={118} width={28} height={10} rx={5} fill="#16202E" />
          {/* brows */}
          <g transform={`translate(0, ${browLift})`}>
            <path d="M 168 186 Q 184 178 198 185" stroke={HAIR} strokeWidth={7} fill="none" strokeLinecap="round" />
            <path
              d={expression === 'eyebrowRaise' ? 'M 222 182 Q 236 170 252 180' : 'M 222 186 Q 236 178 252 185'}
              stroke={HAIR}
              strokeWidth={7}
              fill="none"
              strokeLinecap="round"
            />
          </g>
          {/* eyes */}
          <ellipse cx={184} cy={204} rx={9} ry={eyeH} fill="#26302B" />
          <ellipse cx={236} cy={204} rx={9} ry={eyeH} fill="#26302B" />
          <path d="M 208 206 Q 203 228 210 236 Q 215 232 213 226" fill="none" stroke="#C08B62" strokeWidth={4} strokeLinecap="round" />
          {/* mouth */}
          <g transform="translate(210, 258)">
            <ellipse cx={0} cy={mouthH / 2} rx={15 + flap * 4} ry={mouthH} fill="#3A2A26" />
            {!talking && (
              <path d={`M -17 0 Q 0 ${smile} 17 0`} stroke="#3A2A26" strokeWidth={4} fill="none" strokeLinecap="round" />
            )}
          </g>
        </g>
      </g>
    </svg>
  );
};

const Arms: React.FC<{ pose: DukePose; enter: number; frame: number; fps: number }> = ({
  pose,
  enter,
  frame,
}) => {
  const fizz = Math.sin(frame * 0.4);

  if (pose === 'point') {
    const reach = interpolate(enter, [0, 1], [40, 0]);
    return (
      <g>
        <path d="M 306 356 Q 336 400 330 452" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
        <Can x={318} y={468} fizz={fizz} />
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
        <path d="M 114 356 Q 86 402 92 452" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
        <circle cx={92} cy={466} r={16} fill={SKIN} />
        <g transform={`translate(0, ${lift})`}>
          <path d="M 306 356 Q 330 340 296 300" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
          <Can x={282} y={286} fizz={fizz} />
        </g>
      </g>
    );
  }

  if (pose === 'armsCrossed') {
    return (
      <g>
        <path d="M 116 360 Q 150 410 232 402" stroke={POLO_SHADE} strokeWidth={34} fill="none" strokeLinecap="round" />
        <path d="M 304 360 Q 270 414 190 404" stroke={POLO} strokeWidth={34} fill="none" strokeLinecap="round" />
        <circle cx={236} cy={402} r={15} fill={SKIN} />
        <circle cx={186} cy={404} r={15} fill={SKIN} />
      </g>
    );
  }

  return (
    <g>
      <path d="M 114 356 Q 88 402 94 456" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
      <circle cx={94} cy={470} r={16} fill={SKIN} />
      <path d="M 306 356 Q 334 400 328 452" stroke={POLO_SHADE} strokeWidth={32} fill="none" strokeLinecap="round" />
      <Can x={316} y={468} fizz={fizz} />
    </g>
  );
};

const Can: React.FC<{ x: number; y: number; fizz: number }> = ({ x, y, fizz }) => (
  <g transform={`translate(${x}, ${y})`}>
    <circle cx={0} cy={-14} r={16} fill={SKIN} />
    <rect x={-15} y={-12} width={30} height={50} rx={6} fill={CAN} />
    <rect x={-15} y={-12} width={30} height={8} rx={4} fill="#DDE5E2" />
    <path d="M -8 8 L 8 8 M -8 16 L 5 16" stroke="#0B0E0C" strokeWidth={3} opacity={0.5} />
    {/* fizz zaps */}
    <g opacity={0.6} stroke="#DDE5E2" strokeWidth={3} strokeLinecap="round" fill="none">
      <path d={`M -6 -20 l ${2 + fizz * 2} -8`} />
      <path d={`M 6 -22 l ${-2 - fizz * 2} -9`} />
    </g>
  </g>
);
