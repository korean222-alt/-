import React from 'react';
import { Img, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { alpha } from '../theme';
import { usePalette } from '../palette';
import type { Product } from '../types';

/**
 * 상품 그림 자리.
 *
 * 지금은 쓸 수 있는 상품 이미지가 없다 (쿠팡 오픈API가 누적 판매 15만원
 * 뒤에 열리고, 상세페이지 이미지는 판매자 저작물이라 못 쓴다).
 * 그래서 image가 없으면 emoji + 그라데이션 카드로 대신 그린다.
 * API가 열리면 image만 채우면 되고 이 컴포넌트는 안 바꿔도 된다.
 */
export const ProductVisual: React.FC<{
  product: Product;
  from?: number;
  size?: number;
  tint: string;
}> = ({ product, from = 0, size = 460, tint }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pal = usePalette();

  const p = spring({
    frame: frame - from,
    fps,
    config: { damping: 200, mass: 0.6 },
  });
  // 살아있게 보이도록 아주 느린 호흡
  const breathe = 1 + Math.sin((frame - from) / 26) * 0.012;

  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: 44,
        overflow: 'hidden',
        position: 'relative',
        background: `linear-gradient(150deg, ${alpha(tint, 0.23)} 0%, ${pal.surfaceHi} 55%, ${pal.surface} 100%)`,
        border: `3px solid ${alpha(tint, 0.33)}`,
        boxShadow:
          pal.mode === 'dark'
            ? `0 30px 80px rgba(0,0,0,0.55), 0 0 60px ${alpha(tint, 0.13)}`
            : '0 12px 32px rgba(0,0,0,0.10)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        opacity: p,
        transform: `scale(${interpolate(p, [0, 1], [0.86, 1]) * breathe}) rotate(${interpolate(
          p,
          [0, 1],
          [-3, 0]
        )}deg)`,
        flexShrink: 0,
      }}
    >
      {product.image ? (
        <Img
          src={product.image}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        />
      ) : (
        <span style={{ fontSize: size * 0.42, lineHeight: 1 }}>{product.emoji ?? '🛍️'}</span>
      )}
      {/* 유리 반사 */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            pal.mode === 'dark'
              ? 'linear-gradient(135deg, rgba(255,255,255,0.18) 0%, rgba(255,255,255,0) 42%)'
              : 'linear-gradient(135deg, rgba(255,255,255,0.55) 0%, rgba(255,255,255,0) 46%)',
          pointerEvents: 'none',
        }}
      />
    </div>
  );
};
