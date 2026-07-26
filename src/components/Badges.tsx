import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { alpha, font } from '../theme';
import { usePalette } from '../palette';

/**
 * 판매 페이지에 붙어 있던 배지를 그대로 옮긴다.
 * ("최저가보상", "내일출발", "롤키친타올 1위" 같은 것)
 *
 * 실사용 후기가 없을 때 쓸 수 있는 근거가 이런 것들이다. 내가 만든 말이
 * 아니라 판매처가 붙인 표시라서, 시청자가 링크 눌러 확인하면 그대로 있다.
 * 그래서 **없는 배지를 지어내면 안 된다** — 확인되는 순간 채널이 끝난다.
 */
export const Badges: React.FC<{ items?: string[] | null; from?: number }> = ({
  items,
  from = 0,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pal = usePalette();

  if (!items || items.length === 0) return null;

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, justifyContent: 'center' }}>
      {items.map((label, i) => {
        const pop = spring({
          frame: frame - from - i * 3,
          fps,
          config: { damping: 200, mass: 0.5 },
        });
        return (
          <span
            key={label}
            style={{
              fontFamily: font.body,
              fontWeight: 900,
              fontSize: 32,
              color: pal.mode === 'dark' ? pal.amber : pal.textDim,
              background: pal.mode === 'dark' ? alpha(pal.amber, 0.13) : pal.surface,
              border: `2px solid ${pal.mode === 'dark' ? alpha(pal.amber, 0.38) : pal.line}`,
              borderRadius: 10,
              padding: '7px 16px',
              opacity: pop,
              transform: `translateY(${interpolate(pop, [0, 1], [16, 0])}px)`,
            }}
          >
            {label}
          </span>
        );
      })}
    </div>
  );
};
