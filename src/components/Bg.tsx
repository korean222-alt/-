import React from 'react';
import { AbsoluteFill, useCurrentFrame } from 'remotion';
import { alpha, c, FPS } from '../theme';

/**
 * 배경. 아주 느리게 도는 컬러 덩어리 + 비네트.
 *
 * 두 가지를 노린다.
 * 1) 피드에서 넘기다 걸리려면 썸네일 한 장이 채도로 튀어야 한다.
 *    회색 화면은 그냥 지나간다.
 * 2) 완전히 멈춘 화면은 "끝났나?" 싶어서 스와이프를 부른다.
 *    그래서 눈치 못 챌 정도로만 계속 움직인다.
 */
export const Bg: React.FC<{ tint?: string }> = ({ tint = c.violet }) => {
  const frame = useCurrentFrame();
  const t = frame / FPS;

  const x1 = 52 + Math.sin(t * 0.28) * 14;
  const y1 = 30 + Math.cos(t * 0.22) * 9;
  const x2 = 44 + Math.cos(t * 0.19) * 16;
  const y2 = 76 + Math.sin(t * 0.25) * 8;

  return (
    <AbsoluteFill style={{ backgroundColor: c.bg }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(58% 42% at ${x1}% ${y1}%, ${alpha(tint, 0.8)} 0%, ${alpha(
            tint,
            0.2
          )} 45%, transparent 72%),
                       radial-gradient(62% 44% at ${x2}% ${y2}%, ${alpha(
                         c.pink,
                         0.6
                       )} 0%, ${alpha(c.violet, 0.18)} 48%, transparent 74%)`,
        }}
      />
      {/* 가장자리만 눌러서 가운데 글씨가 뜨게 만든다. 전체를 덮으면 색이 죽는다. */}
      <AbsoluteFill
        style={{
          background:
            'radial-gradient(120% 78% at 50% 46%, transparent 34%, rgba(0,0,0,0.62) 100%)',
        }}
      />
      {/* 아주 옅은 필름 그레인 — 그라데이션 띠(밴딩)를 가려준다 */}
      <AbsoluteFill
        style={{
          opacity: 0.05,
          backgroundImage:
            "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='3'/%3E%3C/filter%3E%3Crect width='140' height='140' filter='url(%23n)'/%3E%3C/svg%3E\")",
        }}
      />
    </AbsoluteFill>
  );
};
