import React from 'react';
import { spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { colors, type } from '../theme';
import type { LessonManifest } from '../types';

// End card: the grounding for the whole lesson — ACS task code(s) plus the
// governing FAA source — with the study-aid disclaimer.

export const SourcesCard: React.FC<{ lesson: LessonManifest }> = ({ lesson }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const cardIn = spring({ frame, fps, config: { damping: 13, stiffness: 120 } });
  const acs = lesson.references.acs.join(' · ');

  return (
    <div style={{ padding: '70px 70px 0', opacity: cardIn, transform: `scale(${0.94 + cardIn * 0.06})` }}>
      <div style={{ ...type.placard, color: colors.amber, marginBottom: 26 }}>SOURCES</div>
      <div
        style={{
          background: colors.panel,
          border: `2px solid ${colors.panelEdge}`,
          borderRadius: 24,
          padding: '40px 44px',
          display: 'flex',
          flexDirection: 'column',
          gap: 34,
        }}
      >
        <div>
          <div style={{ ...type.placard, fontSize: 24, color: colors.inkDim, marginBottom: 10 }}>
            INSTRUMENT RATING ACS (FAA-S-ACS-8C)
          </div>
          <div style={{ ...type.subtitle, fontWeight: 800, color: colors.green }}>{acs}</div>
        </div>
        <div style={{ height: 2, background: colors.panelEdge }} />
        <div>
          <div style={{ ...type.placard, fontSize: 24, color: colors.inkDim, marginBottom: 10 }}>
            FAA REFERENCE
          </div>
          <div style={{ ...type.subtitle, fontWeight: 800, color: colors.ink }}>
            {lesson.references.faa.source}
          </div>
          <div style={{ ...type.chip, color: colors.inkDim, marginTop: 8 }}>
            {lesson.references.faa.title}
          </div>
        </div>
      </div>
      <div style={{ ...type.chip, fontSize: 28, color: colors.inkDim, marginTop: 30 }}>
        Study aid — always verify against current FAA publications.
      </div>
    </div>
  );
};
