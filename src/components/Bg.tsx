import React from 'react';
import { AbsoluteFill, useCurrentFrame } from 'remotion';
import { alpha, FPS } from '../theme';
import { usePalette } from '../palette';

/**
 * 배경.
 *
 * 두 가지를 노린다.
 * 1) 피드에서 넘기다 걸리려면 화면이 튀어야 한다
 * 2) 완전히 멈춘 화면은 "끝났나?" 싶어서 스와이프를 부른다.
 *    그래서 눈치 못 챌 정도로만 계속 움직인다
 *
 * 밝은 테마에서는 흰 바탕을 거의 그대로 두고 색을 아주 옅게만 깐다.
 * 커머스에서 신뢰는 흰 배경에서 나오고, 여기에 색을 얹는 순간 광고가 된다.
 */
export const Bg: React.FC<{ tint?: string }> = ({ tint }) => {
  const frame = useCurrentFrame();
  const p = usePalette();
  const t = frame / FPS;
  const color = tint ?? p.accent;

  const x1 = 52 + Math.sin(t * 0.28) * 14;
  const y1 = 30 + Math.cos(t * 0.22) * 9;
  const x2 = 44 + Math.cos(t * 0.19) * 16;
  const y2 = 76 + Math.sin(t * 0.25) * 8;

  if (p.mode === 'light') {
    return (
      <AbsoluteFill style={{ backgroundColor: p.bg }}>
        <AbsoluteFill
          style={{
            background: `radial-gradient(70% 46% at ${x1}% ${y1}%, ${alpha(color, 0.1)} 0%, transparent 70%),
                         radial-gradient(64% 42% at ${x2}% ${y2}%, ${alpha(color, 0.06)} 0%, transparent 72%)`,
          }}
        />
        {/* 아래쪽만 아주 살짝 눌러서 화면이 붕 뜨지 않게 한다 */}
        <AbsoluteFill
          style={{
            background: `linear-gradient(180deg, transparent 62%, ${alpha('#8B95A1', 0.09)} 100%)`,
          }}
        />
      </AbsoluteFill>
    );
  }

  return (
    <AbsoluteFill style={{ backgroundColor: p.bg }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(58% 42% at ${x1}% ${y1}%, ${alpha(color, 0.8)} 0%, ${alpha(
            color,
            0.2
          )} 45%, transparent 72%),
                       radial-gradient(62% 44% at ${x2}% ${y2}%, ${alpha(
                         p.hot,
                         0.6
                       )} 0%, ${alpha(p.accent, 0.18)} 48%, transparent 74%)`,
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
