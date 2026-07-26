import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import { TimedBg } from '../components/TimedBg';
import { BigText } from '../components/BigText';
import { PriceTag } from '../components/PriceTag';
import { ProductVisual } from '../components/ProductVisual';
import { Disclosure } from '../components/Disclosure';
import { alpha, c, font, s, SAFE, CONTENT_W } from '../theme';
import type { Product, VersusProps } from '../types';

/**
 * 비교 포맷 (싼 것 vs 비싼 것).
 *
 * "얼마 차이인데 뭐가 다른데?"는 사람들이 실제로 검색하는 질문이라
 * 댓글이 잘 붙는다. 댓글은 알고리즘이 좋아하는 신호다.
 * 결론을 마지막에 두는 게 중요 — 먼저 말하면 볼 이유가 사라진다.
 */

const HOOK = s(2.0);
const COMPARE = s(6.5);
const VERDICT = s(3.0);
const OUTRO = s(1.8);

export const versusDuration = () => HOOK + COMPARE + VERDICT + OUTRO;

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

const Side: React.FC<{
  product: Product;
  tint: string;
  label: string;
  from: number;
}> = ({ product, tint, label, from }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - from, fps, config: { damping: 200, mass: 0.55 } });

  return (
    <div
      style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        textAlign: 'center',
        gap: 20,
        opacity: p,
        transform: `translateY(${interpolate(p, [0, 1], [40, 0])}px)`,
      }}
    >
      <div
        style={{
          fontFamily: font.body,
          fontWeight: 700,
          fontSize: 30,
          color: tint,
          border: `2px solid ${alpha(tint, 0.45)}`,
          borderRadius: 8,
          padding: '6px 16px',
        }}
      >
        {label}
      </div>
      <ProductVisual product={product} tint={tint} size={300} from={from + 2} />
      <div style={{ fontFamily: font.head, fontSize: 54, color: c.text, lineHeight: 1.1 }}>
        {product.name}
      </div>
      <PriceTag price={product.price} from={from + 8} tint={tint} size={52} />
      <div
        style={{
          fontFamily: font.body,
          fontSize: 32,
          fontWeight: 700,
          color: c.textDim,
          lineHeight: 1.32,
        }}
      >
        {product.punch}
      </div>
    </div>
  );
};

export const VersusShort: React.FC<VersusProps> = ({
  hook,
  left,
  right,
  verdict,
  cta,
}) => {
  const verdictFrom = HOOK + COMPARE;

  return (
    <AbsoluteFill style={{ backgroundColor: c.bg }}>
      <TimedBg
        segments={[
          { from: 0, tint: c.violet },
          { from: HOOK, tint: c.mint },
          { from: verdictFrom, tint: c.gold },
        ]}
      />

      <Sequence durationInFrames={HOOK}>
        <Section style={{ justifyContent: 'center' }}>
          <div style={{ width: CONTENT_W }}>
            <BigText text={hook} size={110} instantFirstWord stagger={2} />
          </div>
        </Section>
      </Sequence>

      <Sequence from={HOOK} durationInFrames={COMPARE}>
        <Section style={{ justifyContent: 'space-between' }}>
          <div style={{ height: 10 }} />
          <div
            style={{
              width: CONTENT_W,
              display: 'flex',
              alignItems: 'flex-start',
              gap: 24,
              marginTop: -40,
            }}
          >
            <Side product={left} tint={c.mint} label="싼 거" from={0} />
            <div
              style={{
                fontFamily: font.head,
                fontSize: 64,
                color: alpha(c.text, 0.35),
                alignSelf: 'center',
              }}
            >
              VS
            </div>
            <Side product={right} tint={c.amber} label="비싼 거" from={10} />
          </div>
          <Disclosure />
        </Section>
      </Sequence>

      <Sequence from={verdictFrom} durationInFrames={VERDICT}>
        <Section style={{ justifyContent: 'center' }}>
          <div style={{ width: CONTENT_W }}>
            <div
              style={{
                fontFamily: font.body,
                fontWeight: 900,
                fontSize: 34,
                color: c.gold,
                letterSpacing: '0.06em',
                marginBottom: 24,
              }}
            >
              결론
            </div>
            <BigText text={verdict} size={98} instantFirstWord stagger={2} />
          </div>
        </Section>
      </Sequence>

      <Sequence from={verdictFrom + VERDICT} durationInFrames={OUTRO}>
        <Section style={{ justifyContent: 'center' }}>
          <div style={{ width: CONTENT_W }}>
            <BigText text={cta} size={88} instantFirstWord stagger={2} />
          </div>
        </Section>
      </Sequence>
    </AbsoluteFill>
  );
};
