import React from 'react';
import { alpha, c } from '../theme';

/**
 * 상단 진행 표시. "앞으로 몇 개 남았는지"를 보여주면
 * 끝까지 보려는 완주 욕구가 생긴다 — 시청 완료율에 직접 붙는 장치다.
 * 유튜브 UI가 하단을 먹으므로 반드시 위쪽에 둔다.
 */
export const ProgressDots: React.FC<{
  total: number;
  current: number;
  tint?: string;
}> = ({ total, current, tint = c.gold }) => (
  <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
    {Array.from({ length: total }).map((_, i) => {
      const done = i <= current;
      return (
        <div
          key={i}
          style={{
            width: i === current ? 56 : 26,
            height: 10,
            borderRadius: 99,
            background: done ? tint : 'rgba(255,255,255,0.22)',
            boxShadow: i === current ? `0 0 22px ${alpha(tint, 0.67)}` : 'none',
            transition: 'none',
          }}
        />
      );
    })}
  </div>
);
