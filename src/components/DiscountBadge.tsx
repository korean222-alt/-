import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { alpha, font } from '../theme';
import { usePalette } from '../palette';

export const discountPct = (originalPrice: number, price: number) =>
  Math.max(0, Math.round((1 - price / originalPrice) * 100));

/**
 * 할인율. 0프레임에 화면에서 가장 큰 요소로 박힌다.
 *
 * 스와이프를 멈추는 건 상품명이 아니라 숫자다. "무선 무드등"은 넘기고
 * "-67%"는 멈춘다. 그래서 후킹 자리를 상품이 아니라 할인율에 준다.
 */
export const DiscountBadge: React.FC<{
  pct: number;
  from?: number;
  size?: number;
}> = ({ pct, from = 0, size = 180 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pal = usePalette();
  const p = spring({
    frame: frame - from,
    fps,
    config: { damping: 11, mass: 0.6, stiffness: 170 },
  });

  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'baseline',
        fontFamily: font.head,
        color: pal.hot,
        lineHeight: 0.9,
        letterSpacing: '-0.04em',
        transform: `scale(${interpolate(p, [0, 1], [0.55, 1])}) rotate(${interpolate(
          p,
          [0, 1],
          [-6, -3]
        )}deg)`,
        textShadow:
          pal.mode === 'dark'
            ? `0 0 80px ${alpha(pal.hot, 0.55)}, 0 14px 40px rgba(0,0,0,0.65)`
            : 'none',
        opacity: interpolate(p, [0, 0.35], [0, 1], { extrapolateRight: 'clamp' }),
      }}
    >
      <span style={{ fontSize: size * 0.62 }}>-</span>
      <span style={{ fontSize: size }}>{pct}</span>
      <span style={{ fontSize: size * 0.5 }}>%</span>
    </div>
  );
};
