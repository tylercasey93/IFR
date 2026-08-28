import React from 'react';
import { colors } from '../theme';

// Shared 60s-aviation panel chrome: machined corner rivets and the brushed
// aluminum sheen, for any card that wants to read as riveted metal.

export const Rivets: React.FC<{ inset?: number }> = ({ inset = 16 }) => {
  const positions = [
    { top: inset, left: inset },
    { top: inset, right: inset },
    { bottom: inset, left: inset },
    { bottom: inset, right: inset },
  ];
  return (
    <>
      {positions.map((pos, i) => (
        <div
          key={i}
          style={{
            position: 'absolute',
            width: 14,
            height: 14,
            borderRadius: 7,
            background: `radial-gradient(circle at 35% 30%, #E8EDF1, ${colors.aluminumDim} 55%, #4A4F54 100%)`,
            boxShadow: '0 1px 2px rgba(0,0,0,0.7)',
            ...pos,
          }}
        />
      ))}
    </>
  );
};

export const panelStyle: React.CSSProperties = {
  background: `linear-gradient(165deg, rgba(255,255,255,0.06), rgba(255,255,255,0) 40%), ${colors.panel}`,
  border: `2px solid ${colors.panelEdge}`,
};
