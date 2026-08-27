import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors } from '../theme';
import type { DukeExpression, DukePose } from '../types';

// Duke: grizzled veteran CFII. Gray mustache, headset around the neck,
// aviators pushed up, coffee mug that never empties. Rigged with discrete
// poses (arms), expressions (brows/eyes), an audio-agnostic mouth flap while
// `talking`, a blink loop, and a gentle idle bob.

type DukeProps = {
  pose?: DukePose;
  expression?: DukeExpression;
  talking?: boolean;
  /** Overall pixel height of the rendered character. */
  size?: number;
};

const SKIN = '#E5B48D';
const SKIN_SHADE = '#D19E76';
const HAIR = '#C9CDC9';
const JACKET = '#6E4B2E';
const JACKET_DARK = '#5A3C24';
const COLLAR = '#D8C8A8';
const SHIRT = '#3A4A42';
const MUG = '#F2F5F3';

export const Duke: React.FC<DukeProps> = ({
  pose = 'stand',
  expression = 'neutral',
  talking = false,
  size = 560,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Idle bob + tiny sway so he never looks like a sticker.
  const bob = Math.sin((frame / fps) * 2 * Math.PI * 0.45) * 4;
  const sway = Math.sin((frame / fps) * 2 * Math.PI * 0.2) * 1.2;

  // Blink: closed for 4 frames on an ~2.9s cycle (offset so it feels organic).
  const blinkCycle = Math.round(fps * 2.9);
  const blinkPhase = frame % blinkCycle;
  const eyeOpen = blinkPhase < 4 ? 0.12 : 1;

  // Mouth flap while talking: two incommensurate sines give a chatter that
  // doesn't visibly repeat. 0 = closed, 1 = wide open.
  const flap = talking
    ? Math.abs(Math.sin(frame * 0.55)) * (0.35 + 0.65 * Math.abs(Math.sin(frame * 0.23 + 1.3)))
    : 0;
  const mouthH = 3 + flap * 16;

  // Pose entrance: arms spring into position at the start of each scene.
  const enter = spring({ frame, fps, config: { damping: 14, stiffness: 120 } });

  const browLift =
    expression === 'eyebrowRaise' ? -10 : expression === 'squint' ? 4 : 0;
  const eyeH = (expression === 'squint' || expression === 'deadpan' ? 7 : 11) * eyeOpen;
  const smile = expression === 'grin' ? 10 : expression === 'deadpan' ? -2 : 2;

  return (
    <svg
      width={size * 0.78}
      height={size}
      viewBox="0 0 420 540"
      style={{ overflow: 'visible' }}
    >
      <g transform={`translate(${sway}, ${bob})`}>
        {/* ---- torso: bomber jacket ---- */}
        <g>
          <path
            d="M 96 540 L 96 400 Q 96 330 160 316 L 260 316 Q 324 330 324 400 L 324 540 Z"
            fill={JACKET}
          />
          <path d="M 200 322 L 220 322 L 226 540 L 194 540 Z" fill={JACKET_DARK} />
          {/* shirt V */}
          <path d="M 172 318 L 210 318 L 248 318 L 232 372 L 210 388 L 188 372 Z" fill={SHIRT} />
          {/* shearling collar */}
          <path
            d="M 150 322 Q 168 300 196 314 L 210 330 L 176 356 Q 152 344 150 322 Z"
            fill={COLLAR}
          />
          <path
            d="M 270 322 Q 252 300 224 314 L 210 330 L 244 356 Q 268 344 270 322 Z"
            fill={COLLAR}
          />
          {/* wings patch */}
          <g transform="translate(268, 396)" opacity={0.9}>
            <circle r={17} fill={JACKET_DARK} stroke={colors.amber} strokeWidth={2.5} />
            <path d="M -9 2 L 0 -7 L 9 2 L 0 -2 Z" fill={colors.amber} />
          </g>
        </g>

        {/* ---- headset around the neck ---- */}
        <g>
          <path
            d="M 156 330 Q 210 372 264 330"
            stroke="#222623"
            strokeWidth={13}
            fill="none"
            strokeLinecap="round"
          />
          <circle cx={156} cy={330} r={20} fill="#222623" stroke={colors.green} strokeWidth={3} />
          <circle cx={264} cy={330} r={20} fill="#222623" stroke={colors.green} strokeWidth={3} />
          {/* boom mic */}
          <path d="M 264 344 Q 288 366 276 386" stroke="#222623" strokeWidth={6} fill="none" />
          <circle cx={276} cy={388} r={7} fill="#222623" />
        </g>

        {/* ---- arms (pose dependent) ---- */}
        <Arms pose={pose} enter={enter} frame={frame} fps={fps} />

        {/* ---- head ---- */}
        <g transform={`translate(0, ${talking ? Math.sin(frame * 0.3) * 1.2 : 0})`}>
          {/* neck */}
          <rect x={192} y={288} width={36} height={40} rx={10} fill={SKIN_SHADE} />
          {/* face */}
          <path
            d="M 148 190 Q 146 128 210 124 Q 274 128 272 190 Q 274 258 240 286 Q 210 300 180 286 Q 146 258 148 190 Z"
            fill={SKIN}
          />
          {/* gray temples + back of head */}
          <path d="M 148 196 Q 138 160 158 138 Q 152 176 156 210 Q 150 206 148 196 Z" fill={HAIR} />
          <path d="M 272 196 Q 282 160 262 138 Q 268 176 264 210 Q 270 206 272 196 Z" fill={HAIR} />
          {/* balding top with gray sides */}
          <path d="M 156 142 Q 172 116 210 114 Q 248 116 264 142 Q 236 128 210 128 Q 184 128 156 142 Z" fill={HAIR} />
          {/* aviators pushed up on the forehead */}
          <g transform="translate(0, -2)">
            <path d="M 162 142 L 258 142" stroke="#8A7440" strokeWidth={4} />
            <ellipse cx={186} cy={140} rx={20} ry={12} fill="#2B2F2C" stroke="#B89A55" strokeWidth={3.5} />
            <ellipse cx={234} cy={140} rx={20} ry={12} fill="#2B2F2C" stroke="#B89A55" strokeWidth={3.5} />
          </g>
          {/* crow's feet + weathered lines */}
          <path d="M 154 216 L 164 214 M 154 224 L 163 223" stroke={SKIN_SHADE} strokeWidth={2.5} strokeLinecap="round" />
          <path d="M 266 216 L 256 214 M 266 224 L 257 223" stroke={SKIN_SHADE} strokeWidth={2.5} strokeLinecap="round" />
          {/* brows */}
          <g transform={`translate(0, ${browLift})`}>
            <path d="M 168 188 Q 184 180 198 187" stroke={HAIR} strokeWidth={8} fill="none" strokeLinecap="round" />
            <path
              d={
                expression === 'eyebrowRaise'
                  ? 'M 222 184 Q 236 172 252 182'
                  : 'M 222 188 Q 236 180 252 187'
              }
              stroke={HAIR}
              strokeWidth={8}
              fill="none"
              strokeLinecap="round"
            />
          </g>
          {/* eyes */}
          <ellipse cx={184} cy={204} rx={9} ry={eyeH} fill="#26302B" />
          <ellipse cx={236} cy={204} rx={9} ry={eyeH} fill="#26302B" />
          {/* nose */}
          <path d="M 208 206 Q 202 232 210 240 Q 216 236 214 228" fill="none" stroke={SKIN_SHADE} strokeWidth={4} strokeLinecap="round" />
          {/* mouth (behind mustache) */}
          <g transform="translate(210, 262)">
            <ellipse cx={0} cy={mouthH / 2} rx={16 + flap * 4} ry={mouthH} fill="#3A2A26" />
            {!talking && (
              <path
                d={`M -18 0 Q 0 ${smile} 18 0`}
                stroke="#3A2A26"
                strokeWidth={4}
                fill="none"
                strokeLinecap="round"
              />
            )}
          </g>
          {/* the mustache — slight wiggle while talking */}
          <g transform={`translate(210, 252) rotate(${flap * 1.6})`}>
            <path
              d="M -34 4 Q -30 -10 -6 -6 Q 0 -12 6 -6 Q 30 -10 34 4 Q 30 18 12 14 Q 0 10 -12 14 Q -30 18 -34 4 Z"
              fill={HAIR}
            />
          </g>
        </g>
      </g>
    </svg>
  );
};

// Discrete arm poses. Each springs in on scene entry via `enter`.
const Arms: React.FC<{ pose: DukePose; enter: number; frame: number; fps: number }> = ({
  pose,
  enter,
  frame,
  fps,
}) => {
  const steam = Math.sin((frame / fps) * 2 * Math.PI * 0.6);

  if (pose === 'point') {
    const reach = interpolate(enter, [0, 1], [40, 0]);
    return (
      <g>
        {/* right arm down holding mug */}
        <path d="M 306 356 Q 336 400 330 452" stroke={JACKET} strokeWidth={34} fill="none" strokeLinecap="round" />
        <Mug x={318} y={468} steam={steam} />
        {/* left arm extended, pointing off-frame at the diagram */}
        <g transform={`translate(${reach}, ${-reach * 0.4}) rotate(${(1 - enter) * 14}, 120, 380)`}>
          <path d="M 116 358 Q 60 358 24 330" stroke={JACKET} strokeWidth={34} fill="none" strokeLinecap="round" />
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
        <path d="M 114 356 Q 86 402 92 452" stroke={JACKET} strokeWidth={34} fill="none" strokeLinecap="round" />
        <circle cx={92} cy={466} r={16} fill={SKIN} />
        {/* right arm raised, mug near the mustache */}
        <g transform={`translate(0, ${lift})`}>
          <path d="M 306 356 Q 330 340 296 300" stroke={JACKET} strokeWidth={34} fill="none" strokeLinecap="round" />
          <Mug x={282} y={286} steam={steam} />
        </g>
      </g>
    );
  }

  if (pose === 'armsCrossed') {
    return (
      <g>
        <path d="M 116 360 Q 150 410 232 402" stroke={JACKET} strokeWidth={36} fill="none" strokeLinecap="round" />
        <path d="M 304 360 Q 270 414 190 404" stroke={JACKET_DARK} strokeWidth={36} fill="none" strokeLinecap="round" />
        <circle cx={236} cy={402} r={15} fill={SKIN} />
        <circle cx={186} cy={404} r={15} fill={SKIN} />
      </g>
    );
  }

  // stand: relaxed, mug in the right hand
  return (
    <g>
      <path d="M 114 356 Q 88 402 94 456" stroke={JACKET} strokeWidth={34} fill="none" strokeLinecap="round" />
      <circle cx={94} cy={470} r={16} fill={SKIN} />
      <path d="M 306 356 Q 334 400 328 452" stroke={JACKET} strokeWidth={34} fill="none" strokeLinecap="round" />
      <Mug x={316} y={468} steam={steam} />
    </g>
  );
};

const Mug: React.FC<{ x: number; y: number; steam: number }> = ({ x, y, steam }) => (
  <g transform={`translate(${x}, ${y})`}>
    <circle cx={0} cy={-14} r={16} fill={SKIN} />
    <rect x={-20} y={-8} width={40} height={44} rx={7} fill={MUG} />
    <rect x={-20} y={2} width={40} height={9} fill={colors.green} />
    <path d="M 20 2 Q 38 8 20 26" stroke={MUG} strokeWidth={8} fill="none" />
    <g opacity={0.5}>
      <path
        d={`M -6 -16 Q ${-10 + steam * 4} -30 -6 -44`}
        stroke="#FFFFFF"
        strokeWidth={4}
        fill="none"
        strokeLinecap="round"
      />
      <path
        d={`M 7 -16 Q ${11 - steam * 4} -34 7 -50`}
        stroke="#FFFFFF"
        strokeWidth={4}
        fill="none"
        strokeLinecap="round"
        opacity={0.7}
      />
    </g>
  </g>
);
