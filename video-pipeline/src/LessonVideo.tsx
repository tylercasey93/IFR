import React from 'react';
import { AbsoluteFill, Audio, Sequence, staticFile } from 'remotion';
import { BulletScene } from './scenes/BulletScene';
import { ChallengeScene } from './scenes/ChallengeScene';
import { DiagramScene } from './scenes/DiagramScene';
import { RecapScene } from './scenes/RecapScene';
import { SceneShell } from './scenes/SceneShell';
import { SourcesCard } from './scenes/SourcesCard';
import { TitleCard } from './scenes/TitleCard';
import { whooshSrcs } from './sfx';
import type { LessonManifest, SceneManifest } from './types';
import './fonts';

// One full lesson video: a sequence of scenes with per-scene narration audio
// and a ducked music bed underneath.

export const LessonVideo: React.FC<{
  lesson: LessonManifest;
  musicSrc: string | null;
}> = ({ lesson, musicSrc }) => {
  let cursor = 0;
  const sceneStarts = lesson.scenes.map((scene) => {
    const start = cursor;
    cursor += scene.durationInFrames;
    return start;
  });

  return (
    <AbsoluteFill>
      {musicSrc ? (
        <Audio src={staticFile(musicSrc)} volume={0.16} loop />
      ) : null}
      {lesson.scenes.map((scene, i) => (
        <Sequence
          key={scene.id}
          from={sceneStarts[i]}
          durationInFrames={scene.durationInFrames}
          name={`${scene.id} (${scene.kind})`}
        >
          {/* transition whoosh at every scene boundary after the first —
              variant rotates so consecutive transitions never sound identical */}
          {i > 0 && whooshSrcs.length > 0 ? (
            <Audio
              src={staticFile(whooshSrcs[(i - 1) % whooshSrcs.length])}
              volume={0.26}
            />
          ) : null}
          {scene.audioSrc ? <Audio src={staticFile(scene.audioSrc)} /> : null}
          <SceneShell lesson={lesson} scene={scene} sceneStartFrame={sceneStarts[i]}>
            <SceneBody lesson={lesson} scene={scene} />
          </SceneShell>
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};

const SceneBody: React.FC<{ lesson: LessonManifest; scene: SceneManifest }> = ({
  lesson,
  scene,
}) => {
  switch (scene.kind) {
    case 'title':
      return <TitleCard lesson={lesson} />;
    case 'bullets':
      return <BulletScene scene={scene} />;
    case 'diagram':
      return <DiagramScene scene={scene} />;
    case 'recap':
      return <RecapScene scene={scene} />;
    case 'sources':
      return <SourcesCard lesson={lesson} />;
    case 'challenge':
      return <ChallengeScene scene={scene} />;
    default:
      return <BulletScene scene={scene} />;
  }
};
