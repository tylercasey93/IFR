import type React from 'react';
import { Duke } from './Duke';
import { Goose } from './Goose';
import { Mac } from './Mac';
import { Novak } from './Novak';
import { Rae } from './Rae';
import { Vector } from './Vector';
import manifestJson from '../generated/manifest.json';
import type { DukeExpression, DukePose } from '../types';

// The on-screen teacher, selected at manifest-generation time via the
// PERSONA env var (see gen-manifest.mjs). All rigs share Duke's prop API.
export type CharacterProps = {
  pose?: DukePose;
  expression?: DukeExpression;
  talking?: boolean;
  size?: number;
};

const registry: Record<string, React.FC<CharacterProps>> = {
  duke: Duke,
  mac: Mac,
  rae: Rae,
  vector: Vector,
  goose: Goose,
  novak: Novak,
};

const persona = (manifestJson as { persona?: string }).persona ?? 'duke';

export const Character: React.FC<CharacterProps> = registry[persona] ?? Duke;
