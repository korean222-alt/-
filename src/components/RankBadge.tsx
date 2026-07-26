import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { alpha, font } from '../theme';

/** 순위 숫자. 화면에서 가장 큰 요소 — 멀리서도 몇 위인지 바로 읽혀야 한다. */
export const RankBadge: React.FC<{
  rank: number;
  from?: number;
  tint: string;
  size?: number;
}> = ({ rank, from = 0, tint, size = 210 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({
    frame: frame - from,
    fps,
    config: { damping: 14, mass: 0.7, stiffness: 140 },
  });

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'baseline',
        gap: 4,
        fontFamily: font.head,
        color: tint,
        lineHeight: 0.85,
        opacity: interpolate(p, [0, 0.4], [0, 1], { extrapolateRight: 'clamp' }),
        transform: `scale(${interpolate(p, [0, 1], [0.5, 1])})`,
        transformOrigin: 'center bottom',
        textShadow: `0 0 60px ${alpha(tint, 0.4)}, 0 10px 30px rgba(0,0,0,0.6)`,
      }}
    >
      <span style={{ fontSize: size }}>{rank}</span>
      <span style={{ fontSize: size * 0.34 }}>위</span>
    </div>
  );
};
