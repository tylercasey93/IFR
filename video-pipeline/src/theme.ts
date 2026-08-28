// Visual language shared by every lesson video: classic 1960s aviation.
// Black-lacquer panels, bronze/brass primary accents, brushed-aluminum
// secondary accents, warm ivory type — golden-age cockpit meets Pan-Am-era
// graphics.
//
// NOTE: `green` and `amber` are legacy key names kept so every scene/diagram
// call site restyles at once — green now carries the BRONZE primary accent,
// amber carries the ALUMINUM secondary. New chrome should use the explicit
// names below.

export const colors = {
  bg: '#0C0B09',
  panel: '#17140F',
  panelEdge: 'rgba(201,207,212,0.22)', // aluminum bezel line
  ink: '#F3EDE2',
  inkDim: 'rgba(243,237,226,0.6)',
  green: '#C89A5B', // legacy name — bronze primary accent
  amber: '#C9CFD4', // legacy name — brushed aluminum secondary
  bronze: '#C89A5B',
  bronzeDeep: '#8C6A3F',
  aluminum: '#C9CFD4',
  aluminumDim: '#9AA1A8',
  red: '#B3432F', // oxblood warning
  captionHighlight: '#C89A5B',
};

export const fontFamily = "'Inter', 'Helvetica Neue', Arial, sans-serif";
export const displayFamily = "'Oswald', 'Arial Narrow', 'Inter', sans-serif";

export const type = {
  title: { fontFamily: displayFamily, fontWeight: 600, fontSize: 100, lineHeight: 1.04, letterSpacing: '0.01em', textTransform: 'uppercase' as const },
  subtitle: { fontFamily, fontWeight: 600, fontSize: 46, lineHeight: 1.25 },
  bullet: { fontFamily, fontWeight: 600, fontSize: 52, lineHeight: 1.25 },
  caption: { fontFamily, fontWeight: 800, fontSize: 58, lineHeight: 1.15 },
  placard: { fontFamily: displayFamily, fontWeight: 500, fontSize: 32, letterSpacing: '0.28em', textTransform: 'uppercase' as const },
  chip: { fontFamily, fontWeight: 600, fontSize: 34 },
} as const;

// Brushed-metal sheen + rivets shared by panel chrome.
export const brushedPanel = {
  background:
    `linear-gradient(165deg, rgba(255,255,255,0.05), rgba(255,255,255,0) 35%), ${colors.panel}`,
  border: `2px solid ${colors.panelEdge}`,
} as const;

export const VIDEO = { width: 1080, height: 1920, fps: 30 } as const;
