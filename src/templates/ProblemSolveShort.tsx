import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from 'remotion';
import { TimedBg, type BgSegment } from '../components/TimedBg';
import { BigText } from '../components/BigText';
import { PriceTag } from '../components/PriceTag';
import { ProductVisual } from '../components/ProductVisual';
import { Disclosure } from '../components/Disclosure';
import { alpha, c, font, s, SAFE, CONTENT_W } from '../theme';
import type { ProblemSolveProps } from '../types';

/**
 * 문제 → 해결 포맷.
 *
 * 순위형이 "궁금해서" 붙잡는다면 이건 "내 얘기라서" 붙잡는다.
 * 첫 컷에 시청자 상황을 그대로 찍어주면 스크롤이 멈춘다.
 * 순위형보다 짧게 끝내는 게 핵심 — 완결이 빠를수록 완료율이 올라간다.
 */

const PROBLEM = s(2.4);
const ITEM = s(3.4);
const OUTRO = s(1.8);

export const problemSolveDuration = (count: number) =>
  PROBLEM + ITEM * count + OUTRO;

const Section: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({
  children,
  style,
}) => (
  <AbsoluteFill
    style={{
      padding: `${SAFE.top}px ${SAFE.right}px ${SAFE.bottom}px ${SAFE.left}px`,
      alignItems: 'center',
      ...style,
    }}
  >
    {children}
  </AbsoluteFill>
);

const Problem: React.FC<{ problem: string; problemDetail?: string }> = ({
  problem,
  problemDetail,
}) => {
  const frame = useCurrentFrame();
  const out = interpolate(frame, [PROBLEM - 6, PROBLEM], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // 문제 제시 구간은 화면이 미세하게 떨린다. 불편한 상황이라는 신호.
  const shake = Math.sin(frame * 0.9) * interpolate(frame, [0, 20], [5, 0], {
    extrapolateRight: 'clamp',
  });

  return (
    <Section style={{ justifyContent: 'center', opacity: out }}>
      <div style={{ width: CONTENT_W, transform: `translateX(${shake}px)` }}>
        <div
          style={{
            display: 'inline-block',
            fontFamily: font.body,
            fontWeight: 700,
            fontSize: 34,
            color: c.pink,
            border: `2px solid ${alpha(c.pink, 0.5)}`,
            background: alpha(c.pink, 0.12),
            padding: '8px 20px',
            borderRadius: 10,
            marginBottom: 28,
          }}
        >
          이거 내 얘기면
        </div>
        <BigText text={problem} size={112} instantFirstWord stagger={2} />
        {problemDetail ? (
          <div
            style={{
              marginTop: 30,
              fontFamily: font.body,
              fontSize: 46,
              fontWeight: 700,
              color: c.textDim,
              opacity: interpolate(frame, [8, 20], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
            }}
          >
            {problemDetail}
          </div>
        ) : null}
      </div>
    </Section>
  );
};

const Solution: React.FC<{
  product: Parameters<typeof ProductVisual>[0]['product'];
  index: number;
  total: number;
  duration: number;
  tint: string;
}> = ({ product, index, total, duration, tint }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const enter = spring({ frame, fps, config: { damping: 200, mass: 0.5 } });
  const exit = interpolate(frame, [duration - 6, duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.in(Easing.cubic),
  });
  const y = interpolate(enter, [0, 1], [90, 0]) + exit * 70;

  return (
    <Section style={{ justifyContent: 'space-between' }}>
      <div
        style={{
          fontFamily: font.body,
          fontWeight: 700,
          fontSize: 34,
          color: alpha(c.text, 0.55),
          letterSpacing: '0.04em',
          opacity: 1 - exit,
        }}
      >
        해결 {index + 1} / {total}
      </div>

      <div
        style={{
          width: CONTENT_W,
          display: 'flex',
          alignItems: 'center',
          gap: 36,
          opacity: enter * (1 - exit),
          transform: `translateY(${y}px)`,
          marginTop: -30,
        }}
      >
        <ProductVisual product={product} tint={tint} size={330} from={2} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <BigText text={product.name} size={72} from={3} stagger={2} lineHeight={1.08} />
          <div
            style={{
              marginTop: 18,
              fontFamily: font.body,
              fontSize: 38,
              fontWeight: 700,
              color: c.textDim,
              lineHeight: 1.3,
              opacity: interpolate(frame, [8, 18], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
            }}
          >
            {product.punch}
          </div>
          <div style={{ marginTop: 22 }}>
            <PriceTag price={product.price} from={12} tint={tint} size={58} />
          </div>
        </div>
      </div>

      <Disclosure />
    </Section>
  );
};

export const ProblemSolveShort: React.FC<ProblemSolveProps> = ({
  problem,
  problemDetail,
  items,
  cta,
}) => {
  const tints = [c.mint, c.amber, c.pink, c.violet];
  const segments: BgSegment[] = [{ from: 0, tint: c.pink }];
  let cursor = PROBLEM;
  const scenes = items.map((product, i) => {
    const from = cursor;
    cursor += ITEM;
    segments.push({ from, tint: product.tint ?? tints[i % tints.length] });
    return { product, from, tint: product.tint ?? tints[i % tints.length] };
  });
  segments.push({ from: cursor, tint: c.mint });

  return (
    <AbsoluteFill style={{ backgroundColor: c.bg }}>
      <TimedBg segments={segments} />

      <Sequence durationInFrames={PROBLEM}>
        <Problem problem={problem} problemDetail={problemDetail} />
      </Sequence>

      {scenes.map((sc, i) => (
        <Sequence key={sc.product.name} from={sc.from} durationInFrames={ITEM}>
          <Solution
            product={sc.product}
            index={i}
            total={items.length}
            duration={ITEM}
            tint={sc.tint}
          />
        </Sequence>
      ))}

      <Sequence from={cursor} durationInFrames={OUTRO}>
        <Section style={{ justifyContent: 'center' }}>
          <div style={{ width: CONTENT_W }}>
            <BigText text={cta} size={92} instantFirstWord stagger={2} />
          </div>
        </Section>
      </Sequence>
    </AbsoluteFill>
  );
};
