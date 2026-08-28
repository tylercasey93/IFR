// Loads the bundled Inter weights from public/fonts before rendering starts.
import { loadFont } from '@remotion/fonts';
import { staticFile } from 'remotion';

export const fontsReady = Promise.all([
  ...[400, 600, 800].map((weight) =>
    loadFont({
      family: 'Inter',
      url: staticFile(`fonts/Inter-${weight}.woff2`),
      weight: String(weight),
    })
  ),
  ...[500, 600].map((weight) =>
    loadFont({
      family: 'Oswald',
      url: staticFile(`fonts/Oswald-${weight}.woff2`),
      weight: String(weight),
    })
  ),
]);
