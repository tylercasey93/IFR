import type React from 'react';
import { AltimeterMinimums } from './AltimeterMinimums';
import { ApproachPlateProfile } from './ApproachPlateProfile';
import { HoldingPattern } from './HoldingPattern';
import { Hsi } from './Hsi';
import { RouteAltitude } from './RouteAltitude';
import { Timeline } from './Timeline';

// Maps a lesson JSON diagram.type to its animated component. Unknown types
// simply render nothing (DiagramScene guards), so content can reference new
// diagrams before they exist without breaking renders.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const diagramRegistry: Record<string, React.FC<any>> = {
  holdingPattern: HoldingPattern,
  hsi: Hsi,
  approachPlateProfile: ApproachPlateProfile,
  altimeterMinimums: AltimeterMinimums,
  routeAltitude: RouteAltitude,
  timeline: Timeline,
};
