// Visual language shared by every lesson video. Colors mirror the IFR
// FlashCards app theme (App/Theme/Theme.swift) so the feed feels native:
// instrument green accent, caution amber, near-black panel.

export const colors = {
  bg: '#0B0E0C',
  panel: '#1A1F1C',
  panelEdge: 'rgba(255,255,255,0.08)',
  ink: '#F2F5F3',
  inkDim: 'rgba(242,245,243,0.62)',
  green: '#5CC78C',
  amber: '#F5BA3B',
  red: '#E4574B',
  captionHighlight: '#5CC78C',
};

export const fontFamily = "'Inter', 'Helvetica Neue', Arial, sans-serif";

export const type = {
  title: { fontFamily, fontWeight: 800, fontSize: 96, lineHeight: 1.05, letterSpacing: '-0.02em' },
  subtitle: { fontFamily, fontWeight: 600, fontSize: 46, lineHeight: 1.25 },
  bullet: { fontFamily, fontWeight: 600, fontSize: 52, lineHeight: 1.25 },
  caption: { fontFamily, fontWeight: 800, fontSize: 58, lineHeight: 1.15 },
  placard: { fontFamily, fontWeight: 600, fontSize: 30, letterSpacing: '0.18em' },
  chip: { fontFamily, fontWeight: 600, fontSize: 34 },
} as const;

export const VIDEO = { width: 1080, height: 1920, fps: 30 } as const;
