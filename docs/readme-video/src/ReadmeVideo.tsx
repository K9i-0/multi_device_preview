import {Video} from '@remotion/media';
import {
  AbsoluteFill,
  Easing,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {durationOf, toComp, type Manifest, type Point} from './types';

const SANS = 'Inter, system-ui, sans-serif';
const MONO = '"JetBrains Mono", ui-monospace, monospace';
const ACCENT = '#8B93FF';
const MIRROR = '#5EEAD4';
const BG = '#0A0C12';

const WIN_W = 1520;
const WIN_TOP = 34;

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

const Background: React.FC = () => {
  const frame = useCurrentFrame();
  const drift = Math.sin(frame / 90) * 60;
  return (
    <AbsoluteFill style={{background: BG}}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(900px 600px at ${30 + drift / 20}% 18%, rgba(139,147,255,0.28), transparent 70%),
            radial-gradient(800px 600px at ${75 - drift / 20}% 90%, rgba(94,234,212,0.16), transparent 70%)`,
        }}
      />
      <AbsoluteFill
        style={{
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px)',
          backgroundSize: '48px 48px',
          maskImage: 'radial-gradient(ellipse at center, black 30%, transparent 75%)',
        }}
      />
    </AbsoluteFill>
  );
};

const PhoneGlyph: React.FC<{w: number; h: number; delay: number}> = ({
  w,
  h,
  delay,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = spring({frame: frame - delay, fps, config: {damping: 14, mass: 0.6}});
  return (
    <div
      style={{
        width: w,
        height: h,
        borderRadius: w * 0.16,
        border: `3px solid ${ACCENT}`,
        boxShadow: `0 0 24px rgba(139,147,255,0.45), inset 0 0 18px rgba(139,147,255,0.18)`,
        opacity: p,
        transform: `translateY(${(1 - p) * 40}px) scale(${0.8 + p * 0.2})`,
      }}
    />
  );
};

const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const title = spring({frame: frame - 10, fps, config: {damping: 16}});
  const tagline = interpolate(frame, [26, 40], [0, 1], clamp);
  const out = interpolate(frame, [62, 78], [1, 0], clamp);
  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
        gap: 40,
        opacity: out,
        transform: `scale(${1 + (1 - out) * 0.08})`,
      }}
    >
      <div style={{display: 'flex', alignItems: 'flex-end', gap: 22}}>
        <PhoneGlyph w={78} h={160} delay={0} />
        <PhoneGlyph w={70} h={130} delay={4} />
        <PhoneGlyph w={70} h={130} delay={8} />
        <PhoneGlyph w={78} h={164} delay={12} />
      </div>
      <div
        style={{
          fontFamily: MONO,
          fontWeight: 700,
          fontSize: 92,
          color: 'white',
          letterSpacing: '-0.02em',
          opacity: title,
          transform: `translateY(${(1 - title) * 30}px)`,
        }}
      >
        multi_device_preview
      </div>
      <div
        style={{
          fontFamily: SANS,
          fontWeight: 600,
          fontSize: 40,
          color: 'rgba(255,255,255,0.78)',
          opacity: tagline,
          transform: `translateY(${(1 - tagline) * 16}px)`,
        }}
      >
        Every screen size. One window.{' '}
        <span style={{color: MIRROR}}>Input in sync.</span>
      </div>
    </AbsoluteFill>
  );
};

/** A tap ripple, in footage coordinates. */
const Ripple: React.FC<{at: Point; start: number; color: string; big: boolean}> = ({
  at,
  start,
  color,
  big,
}) => {
  const frame = useCurrentFrame();
  const t = frame - start;
  if (t < 0 || t > 15) return null;
  const r = interpolate(t, [0, 15], [6, big ? 54 : 44], {
    easing: Easing.out(Easing.cubic),
  });
  const o = interpolate(t, [0, 3, 15], [0, 1, 0], clamp);
  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: at[0] - r,
          top: at[1] - r,
          width: r * 2,
          height: r * 2,
          borderRadius: '50%',
          border: `${big ? 4 : 3}px solid ${color}`,
          boxShadow: `0 0 18px ${color}`,
          opacity: o,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: at[0] - 9,
          top: at[1] - 9,
          width: 18,
          height: 18,
          borderRadius: '50%',
          background: color,
          opacity: interpolate(t, [0, 3, 10], [0, 0.9, 0], clamp),
        }}
      />
    </>
  );
};

const KeyBadge: React.FC<{at: Point; start: number; label: string}> = ({
  at,
  start,
  label,
}) => {
  const frame = useCurrentFrame();
  const t = frame - start;
  if (t < 0 || t > 34) return null;
  const o = interpolate(t, [0, 4, 26, 34], [0, 1, 1, 0], clamp);
  return (
    <div
      style={{
        position: 'absolute',
        left: at[0] + 120,
        top: at[1] - 74,
        padding: '6px 16px',
        borderRadius: 10,
        background: '#1B1F2E',
        border: `2px solid ${ACCENT}`,
        boxShadow: '0 6px 0 #0d0f17, 0 10px 30px rgba(0,0,0,0.5)',
        fontFamily: MONO,
        fontWeight: 700,
        fontSize: 26,
        color: 'white',
        opacity: o,
        transform: `translateY(${interpolate(t, [0, 3, 6], [0, 4, 0], clamp)}px)`,
      }}
    >
      {label} ⏎
    </div>
  );
};

const TypingHud: React.FC<{m: Manifest}> = ({m}) => {
  const frame = useCurrentFrame();
  const {from, to, text, at} = m.typing;
  const start = toComp(m, from);
  const end = toComp(m, to);
  if (frame < start - 4 || frame > end + 30) return null;
  const count = Math.min(
    text.length,
    Math.max(0, Math.floor(interpolate(frame, [start, end], [0, text.length]) + 1)),
  );
  const o = interpolate(frame, [start - 4, start, end + 20, end + 30], [0, 1, 1, 0], clamp);
  return (
    <div
      style={{
        position: 'absolute',
        left: at[0] + 120,
        top: at[1] - 74,
        display: 'flex',
        gap: 8,
        opacity: o,
      }}
    >
      {text
        .slice(0, count)
        .split('')
        .map((c, i) => (
          <div
            key={i}
            style={{
              width: 44,
              height: 48,
              borderRadius: 10,
              background: '#1B1F2E',
              border: `2px solid ${ACCENT}`,
              boxShadow: '0 5px 0 #0d0f17',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: MONO,
              fontWeight: 700,
              fontSize: 26,
              color: 'white',
            }}
          >
            {c}
          </div>
        ))}
    </div>
  );
};

const DragTrail: React.FC<{from: Point; to: Point; start: number}> = ({
  from,
  to,
  start,
}) => {
  const frame = useCurrentFrame();
  const t = frame - start;
  if (t < 0 || t > 26) return null;
  const p = interpolate(t, [0, 11], [0, 1], {...clamp, easing: Easing.inOut(Easing.quad)});
  const o = interpolate(t, [0, 3, 16, 26], [0, 1, 1, 0], clamp);
  const x = from[0];
  const y1 = from[1];
  const y2 = from[1] + (to[1] - from[1]) * p;
  const top = Math.min(y1, y2);
  const down = to[1] > from[1];
  return (
    <div style={{position: 'absolute', inset: 0, opacity: o}}>
      <div
        style={{
          position: 'absolute',
          left: x - 7,
          top,
          width: 14,
          height: Math.abs(y2 - y1),
          borderRadius: 7,
          background: `linear-gradient(${down ? '180deg' : '0deg'}, transparent, ${ACCENT})`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: x - 16,
          top: y2 - 16,
          width: 32,
          height: 32,
          borderRadius: '50%',
          background: ACCENT,
          boxShadow: `0 0 24px ${ACCENT}`,
        }}
      />
    </div>
  );
};

const Highlight: React.FC<{m: Manifest}> = ({m}) => {
  const frame = useCurrentFrame();
  const {from, to, box, label} = m.highlight;
  const start = toComp(m, from);
  const end = toComp(m, to);
  if (frame < start || frame > end) return null;
  const o = interpolate(frame, [start, start + 8, end - 8, end], [0, 1, 1, 0], clamp);
  const pulse = 0.6 + 0.4 * Math.sin((frame - start) / 6);
  const [x, y, w, h] = box;
  return (
    <div style={{position: 'absolute', inset: 0, opacity: o}}>
      <div
        style={{
          position: 'absolute',
          left: x,
          top: y,
          width: w,
          height: h,
          borderRadius: 56,
          border: `4px solid ${MIRROR}`,
          boxShadow: `0 0 ${20 + pulse * 30}px rgba(94,234,212,${0.35 + pulse * 0.3})`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: x + w / 2,
          top: y + h - 22,
          transform: 'translateX(-50%)',
          padding: '8px 18px',
          borderRadius: 999,
          background: MIRROR,
          color: '#06221d',
          fontFamily: SANS,
          fontWeight: 800,
          fontSize: 26,
          whiteSpace: 'nowrap',
        }}
      >
        {label}
      </div>
    </div>
  );
};

const Caption: React.FC<{m: Manifest}> = ({m}) => {
  const frame = useCurrentFrame();
  const active = m.captions.find(
    (c) => frame >= toComp(m, c.from) && frame < toComp(m, c.to),
  );
  if (!active) return null;
  const start = toComp(m, active.from);
  const end = toComp(m, active.to);
  const first = active === m.captions[0];
  const last = active === m.captions[m.captions.length - 1];
  const o = interpolate(
    frame,
    [start, start + 7, end - 7, end],
    [first ? 0 : 0.2, 1, 1, last ? 0 : 0.2],
    clamp,
  );
  const y = interpolate(frame, [start, start + 8], [14, 0], {
    ...clamp,
    easing: Easing.out(Easing.cubic),
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        top: 978,
        display: 'flex',
        justifyContent: 'center',
        opacity: o,
        transform: `translateY(${y}px)`,
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 20,
          padding: '12px 28px 12px 14px',
          borderRadius: 999,
          background: 'rgba(14,16,24,0.88)',
          border: '1px solid rgba(255,255,255,0.12)',
          boxShadow: '0 12px 40px rgba(0,0,0,0.45)',
        }}
      >
        <div
          style={{
            padding: '6px 16px',
            borderRadius: 999,
            background: ACCENT,
            color: '#0b0d18',
            fontFamily: MONO,
            fontWeight: 700,
            fontSize: 22,
            textTransform: 'uppercase',
            letterSpacing: '0.04em',
          }}
        >
          {active.kicker}
        </div>
        <div
          style={{
            fontFamily: SANS,
            fontWeight: 600,
            fontSize: 36,
            color: 'white',
            letterSpacing: '-0.01em',
          }}
        >
          {active.text}
        </div>
      </div>
    </div>
  );
};

const FootageWindow: React.FC<{m: Manifest}> = ({m}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const {sourceWidth, sourceHeight, trimBefore, trimAfter} = m.footage;
  const s = WIN_W / sourceWidth;
  const footageEnd = toComp(m, trimAfter);
  const enter = spring({frame: frame - m.footageStart, fps, config: {damping: 18}});
  const exit = interpolate(frame, [footageEnd - 14, footageEnd], [0, 1], {
    ...clamp,
    easing: Easing.in(Easing.cubic),
  });
  if (frame < m.footageStart || frame > footageEnd) return null;
  const push = interpolate(frame, [m.footageStart, footageEnd], [1, 1.025]);
  const scale = (0.9 + enter * 0.1) * push * (1 - exit * 0.1);
  const zoom = interpolate(
    frame,
    [toComp(m, m.camera.from), toComp(m, m.camera.to)],
    [1, m.camera.scale],
    {...clamp, easing: Easing.inOut(Easing.cubic)},
  );
  return (
    <div
      style={{
        position: 'absolute',
        left: (1920 - WIN_W) / 2,
        top: WIN_TOP,
        width: WIN_W,
        height: sourceHeight * s,
        opacity: enter * (1 - exit),
        transform: `translateY(${(1 - enter) * 60}px) scale(${scale})`,
        filter: exit > 0 ? `blur(${exit * 8}px)` : undefined,
        borderRadius: 18,
        overflow: 'hidden',
        boxShadow:
          '0 0 0 1px rgba(255,255,255,0.12), 0 30px 80px rgba(0,0,0,0.6), 0 0 120px rgba(139,147,255,0.18)',
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: sourceWidth,
          height: sourceHeight,
          transform: `scale(${s})`,
          transformOrigin: 'top left',
        }}
      >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          transform: `scale(${zoom})`,
          transformOrigin: `${m.camera.origin[0]}px ${m.camera.origin[1]}px`,
        }}
      >
        <Sequence from={m.footageStart} durationInFrames={trimAfter - trimBefore} layout="none">
          <Video
            src={staticFile(m.footage.src)}
            trimBefore={trimBefore}
            trimAfter={trimAfter}
            muted
            style={{width: sourceWidth, height: sourceHeight}}
          />
        </Sequence>
        <Highlight m={m} />
        {m.drags.map((d, i) => (
          <DragTrail key={i} from={d.from} to={d.to} start={toComp(m, d.frame)} />
        ))}
        {m.taps.map((tap, i) =>
          tap.points.map((p, j) => (
            <Ripple
              key={`${i}-${j}`}
              at={p}
              start={toComp(m, tap.frame) + (j === 0 ? 0 : 2)}
              color={j === 0 ? ACCENT : MIRROR}
              big={j === 0}
            />
          )),
        )}
        <TypingHud m={m} />
        {m.taps
          .filter((t) => t.key)
          .map((t, i) => (
            <KeyBadge key={i} at={t.points[0]} start={toComp(m, t.frame)} label={t.key!} />
          ))}
      </div>
      </div>
    </div>
  );
};

const Outro: React.FC<{m: Manifest}> = ({m}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const card = spring({frame, fps, config: {damping: 16}});
  const chars = Math.floor(Math.max(0, frame - 10) * 1.6);
  let remaining = chars;
  const urlO = interpolate(frame, [62, 74], [0, 1], clamp);
  return (
    <AbsoluteFill
      style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 44}}
    >
      <div
        style={{
          fontFamily: MONO,
          fontWeight: 700,
          fontSize: 64,
          color: 'white',
          opacity: card,
          transform: `translateY(${(1 - card) * 24}px)`,
        }}
      >
        multi_device_preview
      </div>
      <div
        style={{
          width: 1180,
          borderRadius: 18,
          background: '#11141D',
          border: '1px solid rgba(255,255,255,0.12)',
          boxShadow: '0 30px 80px rgba(0,0,0,0.55), 0 0 100px rgba(139,147,255,0.18)',
          overflow: 'hidden',
          opacity: card,
          transform: `scale(${0.94 + card * 0.06})`,
        }}
      >
        <div style={{display: 'flex', gap: 10, padding: '16px 20px', background: '#191D29'}}>
          {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => (
            <div key={c} style={{width: 14, height: 14, borderRadius: 7, background: c}} />
          ))}
        </div>
        <div style={{padding: '30px 40px 36px', display: 'flex', flexDirection: 'column', gap: 18}}>
          {m.outro.commands.map((cmd) => {
            if (remaining <= 0) return null;
            const shown = cmd.slice(0, remaining);
            remaining -= cmd.length + 6;
            const typing = shown.length > 0 && shown.length < cmd.length;
            return (
              <div key={cmd} style={{fontFamily: MONO, fontWeight: 500, fontSize: 36, color: 'white'}}>
                <span style={{color: MIRROR}}>$ </span>
                {shown}
                {typing || (shown.length === cmd.length && cmd === m.outro.commands[m.outro.commands.length - 1])
                  ? frame % 20 < 12 && <span style={{color: ACCENT}}>▍</span>
                  : null}
              </div>
            );
          })}
        </div>
      </div>
      <div
        style={{
          fontFamily: SANS,
          fontWeight: 600,
          fontSize: 34,
          color: 'rgba(255,255,255,0.75)',
          opacity: urlO,
        }}
      >
        <span style={{color: ACCENT}}>{m.outro.url}</span>
      </div>
    </AbsoluteFill>
  );
};

export const ReadmeVideo: React.FC<{manifest: Manifest}> = ({manifest: m}) => {
  const outroStart = toComp(m, m.footage.trimAfter) - 6;
  return (
    <AbsoluteFill>
      <Background />
      <Sequence durationInFrames={m.introFrames + 5}>
        <Intro />
      </Sequence>
      <FootageWindow m={m} />
      <Caption m={m} />
      <Sequence from={outroStart} durationInFrames={durationOf(m) - outroStart}>
        <Outro m={m} />
      </Sequence>
    </AbsoluteFill>
  );
};
