import React from 'react';
import { interpolate, useCurrentFrame, Easing } from 'remotion';
import { alpha, c, font, won, s } from '../theme';

/**
 * 가격이 0에서 실제 값까지 굴러 올라간다.
 *
 * 숫자가 변하는 동안 시선이 그 자리에 묶인다. 정지된 가격표는
 * 0.2초면 다 읽고 눈이 떠나지만, 굴러가는 숫자는 끝을 보게 만든다.
 */
export const PriceTag: React.FC<{
  price: number;
  from?: number;
  tint?: string;
  size?: number;
}> = ({ price, from = 0, tint = c.gold, size = 68 }) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame - from, [0, s(0.7)], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  // 100원 단위로 끊어 굴려야 자릿수가 덜 튀어서 읽힌다.
  const shown = Math.round((price * p) / 100) * 100;

  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'baseline',
        gap: 6,
        padding: '10px 26px',
        borderRadius: 18,
        background: alpha(tint, 0.12),
        border: `2px solid ${alpha(tint, 0.4)}`,
        fontFamily: font.head,
        color: tint,
        fontSize: size,
        letterSpacing: '-0.02em',
        opacity: interpolate(frame - from, [0, 4], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        }),
      }}
    >
      {won(shown)}
      <span style={{ fontFamily: font.body, fontSize: size * 0.52, fontWeight: 700 }}>원</span>
    </div>
  );
};
