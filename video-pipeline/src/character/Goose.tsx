import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import type { DukeExpression, DukePose } from '../types';

// Goose: the mascot — a Canada goose in an aviation headset with a tiny
// white silk scarf. Wings for arms, beak flap for talking, maximum
// shareability. Same rig API as Duke.

type Props = {
  pose?: DukePose;
  expression?: DukeExpression;
  talking?: boolean;
  size?: number;
};

const BODY = '#8A7461';
const BODY_LIGHT = '#B8A48E';
const NECK = '#14110E';
const CHIN = '#F2F5F3';
const BILL = '#1C1712';
const SCARF = '#F2F5F3';

export const Goose: React.FC<Props> = ({
  pose = 'stand',
  expression = 'neutral',
  talking = false,
  size = 560,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bob = Math.sin((frame / fps) * 2 * Math.PI * 0.6) * 5;
  const sway = Math.sin((frame / fps) * 2 * Math.PI * 0.28) * 2;
  const blinkPhase = frame % Math.round(fps * 2.4);
  const eyeOpen = blinkPhase < 4 ? 0.15 : 1;
  const flap = talking
    ? Math.abs(Math.sin(frame * 0.65)) * (0.4 + 0.6 * Math.abs(Math.sin(frame * 0.3 + 0.6)))
    : 0;
  const enter = spring({ frame, fps, config: { damping: 11, stiffness: 250 } });
  // Head tilt: geese never hold still.
  const tilt = Math.sin((frame / fps) * 2 * Math.PI * 0.2) * 4 + (expression === 'eyebrowRaise' ? -8 : 0);

  const eyeH = (expression === 'squint' || expression === 'deadpan' ? 5 : 9) * eyeOpen;

  return (
    <svg width={size * 0.78} height={size} viewBox="0 0 420 540" style={{ overflow: 'visible' }}>
      <g transform={`translate(${sway}, ${bob})`}>
        {/* plump body */}
        <path d="M 104 540 Q 92 420 140 368 Q 186 328 236 340 Q 316 356 322 452 L 326 540 Z" fill={BODY} />
        <path d="M 150 540 Q 148 452 186 408 Q 224 376 262 392 Q 300 412 302 486 L 304 540 Z" fill={BODY_LIGHT} />
        {/* tail feathers */}
        <path d="M 108 470 L 62 442 L 78 480 L 54 486 L 84 508 Z" fill={NECK} />

        <Wings pose={pose} enter={enter} frame={frame} />

        {/* neck + head */}
        <g transform={`rotate(${tilt}, 258, 300)`}>
          <path d="M 236 352 Q 224 260 252 196 L 300 200 Q 296 270 288 348 Q 262 364 236 352 Z" fill={NECK} />
          {/* head */}
          <path d="M 240 196 Q 238 140 278 134 Q 318 138 316 178 Q 316 206 298 214 L 252 212 Q 240 208 240 196 Z" fill={NECK} />
          {/* white chinstrap */}
          <path d="M 252 212 Q 246 178 262 162 Q 282 176 292 212 Q 272 222 252 212 Z" fill={CHIN} />
          {/* bill — flaps when talking */}
          <g transform="translate(310, 176)">
            <path d={`M 0 -6 L 44 ${-4 - flap * 12} L 46 ${2 - flap * 12} L 2 4 Z`} fill={BILL} />
            <path d={`M 0 2 L 44 ${6 + flap * 10} L 40 ${12 + flap * 10} L 0 10 Z`} fill={BILL} />
            {flap > 0.25 && <path d={`M 2 0 L 40 ${flap * 6}`} stroke="#7A2B22" strokeWidth={3} />}
          </g>
          {/* eye */}
          <ellipse cx={288} cy={166} rx={7} ry={eyeH} fill="#F2F5F3" />
          <ellipse cx={290} cy={166} rx={3.5} ry={Math.min(eyeH, 5)} fill="#0B0E0C" />
          {/* skeptical goose brow */}
          {(expression === 'squint' || expression === 'deadpan' || expression === 'eyebrowRaise') && (
            <path d="M 278 154 L 300 150" stroke={CHIN} strokeWidth={4} strokeLinecap="round" />
          )}
          {/* aviation headset perched on the head */}
          <path d="M 246 150 Q 276 118 310 142" stroke="#0E1420" strokeWidth={9} fill="none" strokeLinecap="round" />
          <ellipse cx={246} cy={158} rx={11} ry={14} fill="#0E1420" stroke={colors.bronze} strokeWidth={2} />
          <ellipse cx={310} cy={150} rx={11} ry={14} fill="#0E1420" stroke={colors.bronze} strokeWidth={2} />
          {/* tiny silk scarf at the neck base */}
          <path d="M 240 340 Q 262 356 288 342 L 284 362 Q 262 372 244 360 Z" fill={SCARF} />
          <path d={`M 246 358 Q ${236 + Math.sin(frame * 0.15) * 6} 392 250 414 L 262 400 Q 258 378 260 364 Z`} fill={SCARF} />
        </g>
      </g>
    </svg>
  );
};

const Wings: React.FC<{ pose: DukePose; enter: number; frame: number }> = ({ pose, enter, frame }) => {
  const steam = Math.sin(frame * 0.11);

  if (pose === 'point') {
    const reach = interpolate(enter, [0, 1], [40, 0]);
    return (
      <g>
        <path d="M 292 420 Q 320 440 316 480 L 268 470 Q 282 442 292 420 Z" fill={NECK} opacity={0.9} />
        <g transform={`translate(${reach}, ${-reach * 0.4}) rotate(${(1 - enter) * 16}, 150, 420)`}>
          {/* extended wing with feather fingers */}
          <path d="M 150 400 Q 90 380 34 340 L 44 360 Q 80 392 118 410 L 150 424 Z" fill={NECK} />
          <path d="M 44 342 L 20 322 M 40 352 L 14 340 M 44 362 L 22 360" stroke={NECK} strokeWidth={7} strokeLinecap="round" />
        </g>
      </g>
    );
  }

  if (pose === 'coffeeSip') {
    const lift = interpolate(enter, [0, 1], [60, 0]);
    return (
      <g>
        <path d="M 150 420 Q 120 444 126 484 L 170 472 Q 158 444 150 420 Z" fill={NECK} opacity={0.9} />
        <g transform={`translate(0, ${lift})`}>
          <path d="M 286 420 Q 316 388 292 344 L 258 372 Q 274 398 286 420 Z" fill={NECK} />
          <Cup x={272} y={330} steam={steam} />
        </g>
      </g>
    );
  }

  if (pose === 'armsCrossed') {
    // wings folded neatly over the chest
    return (
      <g>
        <path d="M 156 420 Q 200 452 258 440 L 250 464 Q 196 472 152 442 Z" fill={NECK} />
        <path d="M 288 424 Q 244 458 190 448 L 198 470 Q 248 476 292 448 Z" fill="#241E18" />
      </g>
    );
  }

  return (
    <g>
      {/* wings tucked at the sides */}
      <path d="M 148 416 Q 116 448 124 496 L 168 480 Q 156 446 148 416 Z" fill={NECK} opacity={0.9} />
      <path d="M 292 420 Q 322 448 314 494 L 272 478 Q 284 446 292 420 Z" fill={NECK} opacity={0.9} />
      <Cup x={310} y={500} steam={steam} />
    </g>
  );
};

// A goose with a coffee cup. No one questions it.
const Cup: React.FC<{ x: number; y: number; steam: number }> = ({ x, y, steam }) => (
  <g transform={`translate(${x}, ${y})`}>
    <path d="M -13 -4 L 13 -4 L 10 26 L -10 26 Z" fill="#F2F5F3" />
    <rect x={-13} y={0} width={26} height={6} fill={colors.bronze} />
    <g opacity={0.5} stroke="#FFFFFF" strokeWidth={3} fill="none" strokeLinecap="round">
      <path d={`M 0 -8 Q ${-4 + steam * 4} -20 0 -30`} />
    </g>
  </g>
);
