export type Point = [number, number];

export type Manifest = {
  composition: {id: string; width: number; height: number; fps: number};
  /** Footage frames are the source of truth for every event below. */
  footage: {
    src: string;
    sourceWidth: number;
    sourceHeight: number;
    trimBefore: number;
    trimAfter: number;
  };
  /** Composition frame where footage frame `trimBefore` is shown. */
  footageStart: number;
  introFrames: number;
  outroFrames: number;
  captions: {from: number; to: number; kicker: string; text: string}[];
  taps: {frame: number; key?: string; points: Point[]}[];
  drags: {frame: number; from: Point; to: Point}[];
  typing: {from: number; to: number; text: string; at: Point};
  highlight: {
    from: number;
    to: number;
    box: [number, number, number, number];
    label: string;
  };
  /** Push-in toward a point, in footage coordinates. */
  camera: {from: number; to: number; scale: number; origin: Point};
  outro: {commands: string[]; url: string};
};

export const durationOf = (m: Manifest) =>
  m.footageStart + (m.footage.trimAfter - m.footage.trimBefore) + m.outroFrames;

/** Converts a footage frame to a composition frame. */
export const toComp = (m: Manifest, footageFrame: number) =>
  m.footageStart + footageFrame - m.footage.trimBefore;
