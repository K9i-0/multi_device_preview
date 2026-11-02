import '@fontsource/inter/400.css';
import '@fontsource/inter/600.css';
import '@fontsource/inter/800.css';
import '@fontsource/jetbrains-mono/500.css';
import '@fontsource/jetbrains-mono/700.css';
import {Composition, continueRender, delayRender} from 'remotion';
import manifestJson from './edit-manifest.json';
import {ReadmeVideo} from './ReadmeVideo';
import {durationOf, type Manifest} from './types';

const manifest = manifestJson as Manifest;

const fontsHandle = delayRender('Loading fonts');
Promise.all(
  [
    '400 16px Inter',
    '600 16px Inter',
    '800 16px Inter',
    '500 16px "JetBrains Mono"',
    '700 16px "JetBrains Mono"',
  ].map((font) => document.fonts.load(font)),
).then(() => continueRender(fontsHandle));

export const RemotionRoot: React.FC = () => (
  <Composition
    id={manifest.composition.id}
    component={ReadmeVideo}
    width={manifest.composition.width}
    height={manifest.composition.height}
    fps={manifest.composition.fps}
    durationInFrames={durationOf(manifest)}
    defaultProps={{manifest}}
  />
);
