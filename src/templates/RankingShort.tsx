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
import { ProgressDots } from '../components/ProgressDots';
import { PriceTag } from '../components/PriceTag';
import { ProductVisual } from '../components/ProductVisual';
import { RankBadge } from '../components/RankBadge';
import { Disclosure } from '../components/Disclosure';
import { c, font, rankTint, s, SAFE, CONTENT_W } from '../theme';
import type { Product, RankingProps } from '../types';

/**
 * 역순 카운트다운 (5위 → 1위).
 *
 * 이 포맷을 고른 이유는 하나다. 1위를 마지막에 두면 "1위가 뭔지 궁금해서"
 * 끝까지 본다. 시청 완료율이 쇼츠 노출의 핵심 신호이고, 완료율을
 * 구조적으로 올려주는 포맷은 사실상 이거 하나뿐이다.
 *
 * 반대로 1위를 먼저 보여주면 그 뒤를 볼 이유가 없어서 다 이탈한다.
 */

const HOOK = s(2.0);
const ITEM = s(3.2);
const TOP_ITEM = s(4.6); // 1위는 길게 — 여기까지 온 사람은 안 나간다
const OUTRO = s(2.0);

export const rankingDuration = (count: number) =>
  HOOK + ITEM * Math.max(0, count - 1) + TOP_ITEM + OUTRO;

/** 장면 시작 프레임을 미리 계산해 둔다. 배경 색 전환도 이 값을 쓴다. */
const buildTimeline = (count: number) => {
  const scenes: { rank: number; from: number; duration: number }[] = [];
  let cursor = HOOK;
  for (let i = 0; i < count; i++) {
    const rank = count - i;
    const duration = rank === 1 ? TOP_ITEM : ITEM;
    scenes.push({ rank, from: cursor, duration });
    cursor += duration;
  }
  return { scenes, outroFrom: cursor };
};

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

/** 0프레임부터 글자가 있어야 한다. 여기서 스와이프 이탈이 결정된다. */
const Hook: React.FC<{ hook: string; subHook?: string; items: Product[] }> = ({
  hook,
  subHook,
  items,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const out = interpolate(frame, [HOOK - 6, HOOK], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <Section style={{ justifyContent: 'center', opacity: out }}>
      <div style={{ width: CONTENT_W }}>
        <div
          style={{
            display: 'inline-block',
            fontFamily: font.body,
            fontWeight: 900,
            fontSize: 32,
            color: c.bg,
            background: c.gold,
            padding: '8px 20px',
            borderRadius: 10,
            letterSpacing: '0.06em',
            marginBottom: 26,
          }}
        >
          TOP {items.length}
        </div>

        <BigText text={hook} size={110} instantFirstWord stagger={2} />

        {subHook ? (
          <div
            style={{
              marginTop: 28,
              fontFamily: font.body,
              fontSize: 46,
              fontWeight: 700,
              color: c.amber,
              opacity: interpolate(frame, [6, 16], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
            }}
          >
            {subHook}
          </div>
        ) : null}

        {/* 맛보기 줄. 1위 자리만 물음표로 가려둔다 —
            "1위가 뭔데?"가 끝까지 보게 만드는 유일한 이유다. */}
        <div style={{ display: 'flex', gap: 16, marginTop: 64 }}>
          {[...items].reverse().map((it, i) => {
            const isTop = i === items.length - 1;
            const p = spring({
              frame: frame - 8 - i * 3,
              fps,
              config: { damping: 200, mass: 0.5 },
            });
            return (
              <div
                key={`${it.name}-${i}`}
                style={{
                  width: 124,
                  height: 124,
                  borderRadius: 28,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 56,
                  background: isTop ? `${c.gold}26` : 'rgba(255,255,255,0.07)',
                  border: `2px solid ${isTop ? c.gold : 'rgba(255,255,255,0.14)'}`,
                  color: c.gold,
                  fontFamily: font.head,
                  opacity: p,
                  transform: `translateY(${interpolate(p, [0, 1], [22, 0])}px)`,
                }}
              >
                {isTop ? '?' : (it.emoji ?? '🛍️')}
              </div>
            );
          })}
        </div>
      </div>
    </Section>
  );
};

const ItemScene: React.FC<{
  product: Product;
  rank: number;
  index: number;
  total: number;
  duration: number;
}> = ({ product, rank, index, total, duration }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const tint = product.tint ?? rankTint(rank);
  const isTop = rank === 1;

  // 들어올 때 오른쪽에서 빠르게 밀려 들어온다 (약 0.2초).
  // 느린 전환은 그 구간 자체가 이탈 지점이 된다.
  const enter = spring({ frame, fps, config: { damping: 200, mass: 0.5 } });
  const exit = interpolate(frame, [duration - 6, duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.in(Easing.cubic),
  });

  const x = interpolate(enter, [0, 1], [170, 0]) - exit * 150;
  const opacity = enter * (1 - exit);

  return (
    <Section style={{ justifyContent: 'space-between' }}>
      {/* 상단: 얼마나 남았는지 — 완주 욕구를 만드는 장치 */}
      <div style={{ opacity: 1 - exit }}>
        <ProgressDots total={total} current={index} tint={tint} />
      </div>

      <div
        style={{
          width: CONTENT_W,
          opacity,
          transform: `translateX(${x}px)`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          textAlign: 'center',
          marginTop: -40,
        }}
      >
        <RankBadge rank={rank} tint={tint} size={isTop ? 230 : 175} />

        <div style={{ marginTop: 18 }}>
          <ProductVisual product={product} tint={tint} size={isTop ? 430 : 380} from={2} />
        </div>

        <div style={{ marginTop: 34 }}>
          <BigText
            text={product.name}
            size={isTop ? 92 : 82}
            from={4}
            stagger={2}
            align="center"
            lineHeight={1.08}
          />
        </div>

        <div
          style={{
            marginTop: 20,
            fontFamily: font.body,
            fontSize: 42,
            fontWeight: 700,
            color: c.textDim,
            lineHeight: 1.32,
            opacity: interpolate(frame, [8, 18], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          {product.punch}
        </div>

        <div style={{ marginTop: 26 }}>
          <PriceTag price={product.price} from={12} tint={tint} size={isTop ? 78 : 68} />
        </div>
      </div>

      <Disclosure />
    </Section>
  );
};

const Outro: React.FC<{ cta: string; hook: string }> = ({ cta, hook }) => {
  const frame = useCurrentFrame();
  // 마지막 0.5초에 후킹 화면으로 되돌린다.
  // 루프 재생될 때 이음새가 안 보이면 재시청 수가 올라간다.
  const loopBack = interpolate(frame, [OUTRO - 14, OUTRO], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <>
      <Section style={{ justifyContent: 'center' }}>
        <div style={{ width: CONTENT_W, opacity: 1 - loopBack }}>
          <BigText text={cta} size={92} instantFirstWord stagger={2} />
          <div
            style={{
              marginTop: 30,
              fontFamily: font.body,
              fontSize: 42,
              fontWeight: 700,
              color: c.textDim,
            }}
          >
            저장해두고 하나씩 사면 됩니다
          </div>
        </div>
      </Section>
      <Section style={{ justifyContent: 'center', opacity: loopBack }}>
        <div style={{ width: CONTENT_W }}>
          <BigText text={hook} size={110} stagger={0} />
        </div>
      </Section>
    </>
  );
};

export const RankingShort: React.FC<RankingProps> = ({ hook, subHook, items, cta }) => {
  const total = items.length;
  const { scenes, outroFrom } = buildTimeline(total);
  const ordered = [...items].reverse(); // 화면에는 꼴찌부터

  const bgSegments: BgSegment[] = [
    { from: 0, tint: c.violet },
    ...scenes.map((sc) => ({
      from: sc.from,
      tint: ordered[total - sc.rank]?.tint ?? rankTint(sc.rank),
    })),
    { from: outroFrom, tint: c.gold },
  ];

  return (
    <AbsoluteFill style={{ backgroundColor: c.bg }}>
      <TimedBg segments={bgSegments} />

      <Sequence durationInFrames={HOOK}>
        <Hook hook={hook} subHook={subHook} items={items} />
      </Sequence>

      {scenes.map((sc, i) => (
        <Sequence key={sc.rank} from={sc.from} durationInFrames={sc.duration}>
          <ItemScene
            product={ordered[i]}
            rank={sc.rank}
            index={i}
            total={total}
            duration={sc.duration}
          />
        </Sequence>
      ))}

      <Sequence from={outroFrom} durationInFrames={OUTRO}>
        <Outro cta={cta} hook={hook} />
      </Sequence>
    </AbsoluteFill>
  );
};
