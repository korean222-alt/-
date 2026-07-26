import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { alpha, font } from '../theme';
import { usePalette } from '../palette';

/**
 * 별점 · 리뷰 수 · 역대최저 배지.
 *
 * "내가 써봤는데"를 못 하니까 신뢰를 남의 것으로 빌려온다. 리뷰 1만 건은
 * 내 후기 한 건보다 약하지만, 후기가 아예 없는 것보다는 훨씬 낫다.
 * 숫자는 반드시 실제 값만 넣는다 — 지어내면 그 채널은 거기서 끝난다.
 */
export const TrustRow: React.FC<{
  rating?: number | null;
  reviewCount?: number | null;
  lowestEver?: boolean | null;
  from?: number;
}> = ({ rating, reviewCount, lowestEver, from = 0 }) => {
  const frame = useCurrentFrame();
  const pal = usePalette();
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
          color: pal.mode === 'dark' ? pal.bg : '#FFFFFF',
          background: pal.mode === 'dark' ? pal.gold : pal.hot,
          fontWeight: 900,
          padding: '6px 16px',
          borderRadius: 8,
        }}
      >
        역대 최저가
      </span>
    );
  }
  if (rating !== undefined && rating !== null) {
    chips.push(
      // 밝은 배경에서 금색 글씨는 잘 안 읽힌다. 별만 금색으로 두고
      // 숫자는 본문색으로 뽑아야 한눈에 들어온다.
      <span key="rating" style={{ color: pal.text }}>
        <span style={{ color: pal.gold }}>★</span> {rating.toFixed(1)}
      </span>
    );
  }
  if (reviewCount !== undefined && reviewCount !== null) {
    chips.push(
      <span key="reviews" style={{ color: pal.textDim }}>
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
          {i > 0 ? <span style={{ color: alpha(pal.text, 0.25) }}>·</span> : null}
          {chip}
        </React.Fragment>
      ))}
    </div>
  );
};
