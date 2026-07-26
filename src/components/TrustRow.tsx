import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { alpha, c, font } from '../theme';

/**
 * 별점 · 리뷰 수 · 역대최저 배지.
 *
 * "내가 써봤는데"를 못 하니까 신뢰를 남의 것으로 빌려온다. 리뷰 1만 건은
 * 내 후기 한 건보다 약하지만, 후기가 아예 없는 것보다는 훨씬 낫다.
 * 숫자는 반드시 실제 값만 넣는다 — 지어내면 그 채널은 거기서 끝난다.
 */
export const TrustRow: React.FC<{
  rating?: number;
  reviewCount?: number;
  lowestEver?: boolean;
  from?: number;
}> = ({ rating, reviewCount, lowestEver, from = 0 }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame - from, [0, 8], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const chips: React.ReactNode[] = [];

  if (lowestEver) {
    chips.push(
      <span
        key="lowest"
        style={{
          color: c.bg,
          background: c.gold,
          fontWeight: 900,
          padding: '6px 16px',
          borderRadius: 8,
        }}
      >
        역대 최저가
      </span>
    );
  }
  if (rating !== undefined) {
    chips.push(
      <span key="rating" style={{ color: c.gold }}>
        ★ {rating.toFixed(1)}
      </span>
    );
  }
  if (reviewCount !== undefined) {
    chips.push(
      <span key="reviews" style={{ color: c.textDim }}>
        리뷰 {reviewCount.toLocaleString('ko-KR')}
      </span>
    );
  }

  if (chips.length === 0) return null;

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 18,
        fontFamily: font.body,
        fontSize: 34,
        fontWeight: 700,
        opacity,
      }}
    >
      {chips.map((chip, i) => (
        <React.Fragment key={i}>
          {i > 0 ? <span style={{ color: alpha(c.text, 0.25) }}>·</span> : null}
          {chip}
        </React.Fragment>
      ))}
    </div>
  );
};
