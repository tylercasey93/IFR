import React from 'react';
import { Composition } from 'remotion';
import { LessonVideo } from './LessonVideo';
import manifestJson from './generated/manifest.json';
import type { RenderManifest, LessonManifest } from './types';

const manifest = manifestJson as unknown as RenderManifest;

export const Root: React.FC = () => {
  return (
    <>
      {manifest.lessons.map((lesson: LessonManifest) => (
        <Composition
          key={lesson.id}
          id={lesson.id}
          component={LessonVideo}
          durationInFrames={lesson.durationInFrames}
          fps={manifest.fps}
          width={manifest.width}
          height={manifest.height}
          defaultProps={{ lesson, musicSrc: manifest.musicSrc }}
        />
      ))}
    </>
  );
};
