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
import { PriceDrop } from '../components/PriceDrop';
import { DiscountBadge, discountPct } from '../components/DiscountBadge';
import { TrustRow } from '../components/TrustRow';
import { ProductVisual } from '../components/ProductVisual';
import { Disclosure } from '../components/Disclosure';
import { alpha, c, font, s, SAFE, CONTENT_W } from '../theme';
import type { Deal, DealProps } from '../types';

/**
 * 특가 포맷.
 *
 * 앞의 세 포맷은 전부 "이 상품 좋다"를 파는데, 그건 신뢰 싸움이라
 * 실사용 영상 가진 사람을 못 이긴다. 이 포맷만 파는 게 다르다 —
 * 상품이 아니라 가격을 판다. "지금 싸다"는 검증이 링크 한 번이면
 * 끝나는 사실이라 화자가 누구인지 아무도 안 따진다.
 *
 * 대신 딱 하나를 지켜야 한다: 가격 확인 시점을 반드시 화면에 남길 것.
 * 특가는 몇 시간이면 끝나고, 틀린 가격 한 번이면 채널이 죽는다.
 */

const HOOK = s(1.8);
const DEAL = s(3.6);
const OUTRO = s(1.6);

export const dealDuration = (count: number) => HOOK + DEAL * count + OUTRO;

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

/** 가격 시점. 항상 떠 있어야 한다 — 이게 유일한 방어선이다. */
const CheckedAt: React.FC<{ at: string }> = ({ at }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'flex-start' }}>
    <div
      style={{
        fontFamily: font.body,
        fontSize: 26,
        fontWeight: 700,
        color: c.amber,
        background: alpha(c.amber, 0.12),
        border: `1px solid ${alpha(c.amber, 0.35)}`,
        borderRadius: 8,
        padding: '6px 14px',
      }}
    >
      {at} 가격 · 지금은 다를 수 있어요
    </div>
    <Disclosure />
  </div>
);

const Deadline: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  // 천천히 뛰는 맥박. 빠르게 깜빡이면 싸구려로 보인다.
  const pulse = 0.72 + Math.sin(frame / 7) * 0.28;
  return (
    <div
      style={{
        fontFamily: font.body,
        fontWeight: 900,
        fontSize: 32,
        color: c.pink,
        background: alpha(c.pink, 0.14),
        border: `2px solid ${alpha(c.pink, 0.45)}`,
        borderRadius: 10,
        padding: '8px 18px',
        opacity: pulse,
      }}
    >
      ⏰ {text}
    </div>
  );
};

const Hook: React.FC<{
  hook?: string;
  deadline?: string;
  items: Deal[];
}> = ({ hook, deadline, items }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const out = interpolate(frame, [HOOK - 5, HOOK], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const best = Math.max(...items.map((it) => discountPct(it.originalPrice, it.price)));
  const line = hook ?? `오늘 최대 ${best}% 떨어진 것들`;

  return (
    <Section style={{ justifyContent: 'center', opacity: out }}>
      <div style={{ width: CONTENT_W }}>
        {/* 상품명보다 할인율이 먼저 뜬다. 스크롤을 멈추는 건 숫자다. */}
        <DiscountBadge pct={best} size={210} />
        <div style={{ marginTop: 24 }}>
          <BigText text={line} size={98} instantFirstWord stagger={2} />
        </div>
        <div style={{ display: 'flex', gap: 16, marginTop: 34, alignItems: 'center' }}>
          <div
            style={{
              fontFamily: font.body,
              fontWeight: 900,
              fontSize: 34,
              color: c.bg,
              background: c.mint,
              borderRadius: 10,
              padding: '8px 18px',
              opacity: spring({ frame: frame - 6, fps, config: { damping: 200 } }),
            }}
          >
            {items.length}개
          </div>
          {deadline ? <Deadline text={deadline} /> : null}
        </div>
      </div>
    </Section>
  );
};

const DealScene: React.FC<{
  deal: Deal;
  index: number;
  total: number;
  priceCheckedAt: string;
  deadline?: string;
}> = ({ deal, index, total, priceCheckedAt, deadline }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const tint = deal.tint ?? c.mint;
  const pct = discountPct(deal.originalPrice, deal.price);

  const enter = spring({ frame, fps, config: { damping: 200, mass: 0.5 } });
  const exit = interpolate(frame, [DEAL - 6, DEAL], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.in(Easing.cubic),
  });
  const opacity = enter * (1 - exit);
  const x = interpolate(enter, [0, 1], [150, 0]) - exit * 130;

  return (
    <Section style={{ justifyContent: 'space-between' }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 20,
          opacity: 1 - exit,
          alignSelf: 'stretch',
        }}
      >
        <div
          style={{
            fontFamily: font.body,
            fontWeight: 900,
            fontSize: 34,
            color: alpha(c.text, 0.6),
          }}
        >
          {index + 1} / {total}
        </div>
        {deadline ? <Deadline text={deadline} /> : null}
      </div>

      <div
        style={{
          width: CONTENT_W,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          textAlign: 'center',
          opacity,
          transform: `translateX(${x}px)`,
          marginTop: -30,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 30 }}>
          <ProductVisual product={deal} tint={tint} size={250} from={2} />
          <DiscountBadge pct={pct} from={4} size={150} />
        </div>

        <div style={{ marginTop: 26 }}>
          <BigText
            text={deal.name}
            size={68}
            from={5}
            stagger={2}
            align="center"
            lineHeight={1.1}
          />
        </div>

        {/* 본론. 여기가 이 영상에서 유일하게 파는 지점이다. */}
        <div style={{ marginTop: 22 }}>
          <PriceDrop
            originalPrice={deal.originalPrice}
            price={deal.price}
            from={8}
            tint={tint}
          />
        </div>

        <div style={{ marginTop: 20 }}>
          <TrustRow
            rating={deal.rating}
            reviewCount={deal.reviewCount}
            lowestEver={deal.lowestEver}
            from={s(1.4)}
          />
        </div>
      </div>

      <CheckedAt at={priceCheckedAt} />
    </Section>
  );
};

export const DealShort: React.FC<DealProps> = ({
  hook,
  deadline,
  priceCheckedAt,
  items,
  cta,
}) => {
  const segments: BgSegment[] = [{ from: 0, tint: c.pink }];
  let cursor = HOOK;
  const scenes = items.map((deal) => {
    const from = cursor;
    cursor += DEAL;
    segments.push({ from, tint: deal.tint ?? c.mint });
    return { deal, from };
  });
  segments.push({ from: cursor, tint: c.gold });

  return (
    <AbsoluteFill style={{ backgroundColor: c.bg }}>
      <TimedBg segments={segments} />

      <Sequence durationInFrames={HOOK}>
        <Hook hook={hook} deadline={deadline} items={items} />
      </Sequence>

      {scenes.map((sc, i) => (
        <Sequence key={sc.deal.name} from={sc.from} durationInFrames={DEAL}>
          <DealScene
            deal={sc.deal}
            index={i}
            total={items.length}
            priceCheckedAt={priceCheckedAt}
            deadline={deadline}
          />
        </Sequence>
      ))}

      <Sequence from={cursor} durationInFrames={OUTRO}>
        <Section style={{ justifyContent: 'center' }}>
          <div style={{ width: CONTENT_W }}>
            <BigText text={cta} size={92} instantFirstWord stagger={2} />
            <div
              style={{
                marginTop: 26,
                fontFamily: font.body,
                fontSize: 36,
                fontWeight: 700,
                color: c.textDim,
              }}
            >
              {priceCheckedAt} 기준 · 품절되면 죄송해요
            </div>
          </div>
        </Section>
      </Sequence>
    </AbsoluteFill>
  );
};
