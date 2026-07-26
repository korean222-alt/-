import React from 'react';
import {
  Easing,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import { alpha, font, s, won } from '../theme';
import { usePalette } from '../palette';

/**
 * 원가 → 할인가로 숫자가 떨어진다.
 *
 * 이 컴포넌트가 이 영상의 본론이다. 실사용 영상이 없으면 상품 자체는 못
 * 파니까, 파는 건 가격 낙차 하나다. 그래서 낙차를 글로 설명하지 않고
 * 눈앞에서 떨어뜨린다 — 숫자가 굴러 내려가는 3초가 콘텐츠 전부다.
 */
export const PriceDrop: React.FC<{
  originalPrice: number;
  price: number;
  /** "1롤당 575원" 같은 단가. 총액보다 이게 사람을 움직인다. */
  unitLabel?: string | null;
  freeShipping?: boolean | null;
  from?: number;
  tint?: string;
}> = ({ originalPrice, price, unitLabel, freeShipping, from = 0, tint }) => {
  const frame = useCurrentFrame() - from;
  const { fps } = useVideoConfig();
  const pal = usePalette();
  const color = tint ?? pal.price;

  // 취소선이 좌에서 우로 그어진다
  const strike = interpolate(frame, [s(0.2), s(0.5)], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  // 원가에서 할인가까지 굴러 떨어진다. 끝에서 감속시켜야 착지감이 산다.
  const dropP = interpolate(frame, [s(0.35), s(1.25)], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  const shown = Math.round(
    (originalPrice + (price - originalPrice) * dropP) / 100
  ) * 100;

  // 착지 순간 한 번 튕긴다
  const land = spring({
    frame: frame - s(1.25),
    fps,
    config: { damping: 9, mass: 0.5, stiffness: 180 },
  });
  const scale = 1 + land * 0.06;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
      <div
        style={{
          position: 'relative',
          fontFamily: font.body,
          fontWeight: 700,
          fontSize: 46,
          color: alpha(pal.text, 0.42),
          opacity: interpolate(frame, [0, 4], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
        }}
      >
        {won(originalPrice)}원
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: '52%',
            height: 5,
            borderRadius: 4,
            background: pal.hot,
            transform: `scaleX(${strike})`,
            transformOrigin: 'left center',
          }}
        />
      </div>

      <div
        style={{
          fontFamily: font.head,
          fontSize: 132,
          lineHeight: 1,
          color,
          letterSpacing: '-0.03em',
          transform: `scale(${scale})`,
          textShadow:
            pal.mode === 'dark'
              ? `0 0 70px ${alpha(color, 0.45)}, 0 12px 34px rgba(0,0,0,0.6)`
              : 'none',
          opacity: interpolate(frame, [s(0.3), s(0.45)], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
        }}
      >
        {won(shown)}
        <span style={{ fontFamily: font.body, fontWeight: 700, fontSize: 54 }}>원</span>
      </div>

      {/* 단가는 착지 뒤에 따라 붙는다. 총액을 먼저 보여주고
          "그런데 개당으로 치면"으로 한 번 더 때리는 순서. */}
      {unitLabel || freeShipping ? (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            marginTop: 10,
            opacity: interpolate(frame, [s(1.3), s(1.55)], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          {unitLabel ? (
            <span
              style={{
                fontFamily: font.head,
                fontSize: 52,
                color: pal.mode === 'dark' ? pal.text : color,
                background: alpha(color, pal.mode === 'dark' ? 0.18 : 0.09),
                border: `2px solid ${alpha(color, pal.mode === 'dark' ? 0.45 : 0.3)}`,
                borderRadius: 14,
                padding: '6px 20px',
                letterSpacing: '-0.02em',
              }}
            >
              {unitLabel}
            </span>
          ) : null}
          {freeShipping ? (
            <span
              style={{
                fontFamily: font.body,
                fontWeight: 900,
                fontSize: 34,
                color: pal.mint,
              }}
            >
              무료배송
            </span>
          ) : null}
        </div>
      ) : null}
    </div>
  );
};
