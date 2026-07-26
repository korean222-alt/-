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
import { Badges } from '../components/Badges';
import { ProductVisual } from '../components/ProductVisual';
import { Disclosure } from '../components/Disclosure';
import { alpha, font, s, won, SAFE, CONTENT_W } from '../theme';
import { PaletteProvider, usePalette, type Palette } from '../palette';
import type { Deal, DealProps } from '../types';

/**
 * 특가 포맷.
 *
 * 앞의 세 포맷은 전부 "이 상품 좋다"를 파는데, 그건 신뢰 싸움이라
 * 실사용 영상 가진 사람을 못 이긴다. 이 포맷만 파는 게 다르다 —
 * 상품이 아니라 가격을 판다. "지금 싸다"는 검증이 링크 한 번이면
 * 끝나는 사실이라 화자가 누구인지 아무도 안 따진다.
 *
 * 대신 지켜야 할 게 있다. 화면에 뜨는 모든 문구는 판매 페이지에서
 * 확인된 것만 쓴다. 마감도 재고도 지어내지 않는다 — 확인되는 순간
 * 채널이 끝나고, 허위 표시는 파트너스 약관 위반이기도 하다.
 */

const HOOK = s(1.8);
const DEAL = s(3.6);
/**
 * 상품이 하나뿐이면 장면을 길게 준다.
 *
 * 여러 개를 훑을 땐 다음 게 있어서 빨리 넘겨도 되는데, 단품은 그 화면이
 * 전부다. 3.6초에 끊으면 가격이 착지하자마자 영상이 끝나서 살지 말지
 * 판단할 시간이 없다.
 */
const DEAL_SOLO = s(6.0);
const OUTRO = s(1.6);

const dealSceneLength = (count: number) => (count === 1 ? DEAL_SOLO : DEAL);

export const dealDuration = (count: number) =>
  HOOK + dealSceneLength(count) * count + OUTRO;

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

/**
 * 가격 확인 시점.
 *
 * 처음엔 "지금은 다를 수 있어요"라고 썼는데, 그건 살 마음을 직접 꺾는
 * 문장이었다. 시점만 적어도 방어는 똑같이 되면서 김은 안 빠진다.
 * 정보처럼 읽히지 변명처럼 읽히지 않는다.
 */
const CheckedAt: React.FC<{ at: string }> = ({ at }) => {
  const pal = usePalette();
  return (
    <div
      style={{ display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'flex-start' }}
    >
      <div
        style={{
          fontFamily: font.body,
          fontSize: 26,
          fontWeight: 700,
          color: pal.textDim,
          background: pal.mode === 'dark' ? alpha(pal.text, 0.07) : pal.surface,
          border: `1px solid ${pal.line}`,
          borderRadius: 8,
          padding: '6px 14px',
        }}
      >
        {at} 확인
      </div>
      <Disclosure />
    </div>
  );
};

/**
 * 마감·재고 경고.
 *
 * 판매 페이지에 실제로 그렇게 적혀 있을 때만 넘긴다. 없는 마감을 지어내
 * 붙이면 클릭은 몇 번 더 나오겠지만 그게 마지막 클릭이 된다.
 */
const Urgency: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const pal = usePalette();
  // 천천히 뛰는 맥박. 빠르게 깜빡이면 싸구려로 보인다.
  const pulse = 0.75 + Math.sin(frame / 7) * 0.25;
  return (
    <div
      style={{
        fontFamily: font.body,
        fontWeight: 900,
        fontSize: 32,
        color: pal.mode === 'dark' ? pal.hot : '#FFFFFF',
        background: pal.mode === 'dark' ? alpha(pal.hot, 0.14) : pal.hot,
        border: `2px solid ${pal.mode === 'dark' ? alpha(pal.hot, 0.45) : pal.hot}`,
        borderRadius: 10,
        padding: '8px 18px',
        opacity: pulse,
      }}
    >
      {text}
    </div>
  );
};

const Hook: React.FC<{
  hook?: string | null;
  deadline?: string | null;
  items: Deal[];
}> = ({ hook, deadline, items }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pal = usePalette();
  const out = interpolate(frame, [HOOK - 5, HOOK], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const best = Math.max(...items.map((it) => discountPct(it.originalPrice, it.price)));
  const line = hook || `오늘 최대 ${best}% 떨어진 것들`;

  return (
    <Section style={{ justifyContent: 'center', opacity: out }}>
      <div style={{ width: CONTENT_W }}>
        {/* 상품명보다 할인율이 먼저 뜬다. 스크롤을 멈추는 건 숫자다. */}
        <DiscountBadge pct={best} size={210} />
        <div style={{ marginTop: 24 }}>
          <BigText text={line} size={98} instantFirstWord stagger={2} />
        </div>
        <div style={{ display: 'flex', gap: 16, marginTop: 34, alignItems: 'center' }}>
          {items.length > 1 ? (
            <div
              style={{
                fontFamily: font.body,
                fontWeight: 900,
                fontSize: 34,
                color: pal.mode === 'dark' ? pal.bg : '#FFFFFF',
                background: pal.mode === 'dark' ? pal.mint : pal.text,
                borderRadius: 10,
                padding: '8px 18px',
                opacity: spring({ frame: frame - 6, fps, config: { damping: 200 } }),
              }}
            >
              {items.length}개
            </div>
          ) : null}
          {deadline ? <Urgency text={`⏰ ${deadline}`} /> : null}
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
  deadline?: string | null;
  duration: number;
}> = ({ deal, index, total, priceCheckedAt, deadline, duration }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pal = usePalette();
  const tint = deal.tint ?? pal.price;
  const pct = discountPct(deal.originalPrice, deal.price);

  const enter = spring({ frame, fps, config: { damping: 200, mass: 0.5 } });
  const exit = interpolate(frame, [duration - 6, duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.in(Easing.cubic),
  });
  const opacity = enter * (1 - exit);
  const x = interpolate(enter, [0, 1], [150, 0]) - exit * 130;

  // 재고 경고가 있으면 그게 마감보다 세다. 둘 다 있으면 재고를 쓴다.
  const urgency = deal.stockWarning || deadline;

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
        {/* 단품이면 "1 / 1"은 의미가 없어서 안 그린다 */}
        {total > 1 ? (
          <div
            style={{
              fontFamily: font.body,
              fontWeight: 900,
              fontSize: 34,
              color: alpha(pal.text, 0.6),
            }}
          >
            {index + 1} / {total}
          </div>
        ) : null}
        {urgency ? (
          <Urgency text={deal.stockWarning ? `🔥 ${urgency}` : `⏰ ${urgency}`} />
        ) : null}
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

        <div style={{ marginTop: 16 }}>
          <Badges items={deal.badges} from={7} />
        </div>

        {/* 본론. 여기가 이 영상에서 유일하게 파는 지점이다. */}
        <div style={{ marginTop: 20 }}>
          <PriceDrop
            originalPrice={deal.originalPrice}
            price={deal.price}
            unitLabel={deal.unitLabel}
            freeShipping={deal.freeShipping}
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

/**
 * 마무리.
 *
 * "품절되면 죄송해요"라고 쓴 적이 있는데, 마지막 화면에서 사과를 하면
 * 여태 쌓은 게 무너진다. 대신 원가를 다시 보여준다 — 안 사면 얼마를
 * 더 내야 하는지가 마지막에 남아야 손이 링크로 간다.
 */
const Outro: React.FC<{ cta: string; anchorPrice: number }> = ({ cta, anchorPrice }) => {
  const pal = usePalette();
  return (
    <Section style={{ justifyContent: 'center' }}>
      <div style={{ width: CONTENT_W }}>
        <BigText text={cta} size={92} instantFirstWord stagger={2} />
        <div
          style={{
            marginTop: 26,
            fontFamily: font.head,
            fontSize: 52,
            color: pal.hot,
            letterSpacing: '-0.02em',
          }}
        >
          놓치면 다시 {won(anchorPrice)}원
        </div>
      </div>
    </Section>
  );
};

const DealBody: React.FC<DealProps> = ({ hook, deadline, priceCheckedAt, items, cta }) => {
  const pal = usePalette();
  const segments: BgSegment[] = [{ from: 0, tint: pal.hot }];
  const sceneLen = dealSceneLength(items.length);
  let cursor = HOOK;
  const scenes = items.map((deal) => {
    const from = cursor;
    cursor += sceneLen;
    segments.push({ from, tint: deal.tint ?? pal.price });
    return { deal, from };
  });
  segments.push({ from: cursor, tint: pal.hot });

  return (
    <AbsoluteFill style={{ backgroundColor: pal.bg }}>
      <TimedBg segments={segments} />

      <Sequence durationInFrames={HOOK}>
        <Hook hook={hook} deadline={deadline} items={items} />
      </Sequence>

      {scenes.map((sc, i) => (
        <Sequence key={sc.deal.name} from={sc.from} durationInFrames={sceneLen}>
          <DealScene
            deal={sc.deal}
            index={i}
            total={items.length}
            priceCheckedAt={priceCheckedAt}
            deadline={deadline}
            duration={sceneLen}
          />
        </Sequence>
      ))}

      <Sequence from={cursor} durationInFrames={OUTRO}>
        <Outro cta={cta} anchorPrice={items[0].originalPrice} />
      </Sequence>
    </AbsoluteFill>
  );
};

export const DealShort: React.FC<DealProps> = (props) => (
  <PaletteProvider theme={props.theme ?? 'light'}>
    <DealBody {...props} />
  </PaletteProvider>
);

export type { Palette };
