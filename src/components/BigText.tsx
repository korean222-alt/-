import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { c, font } from '../theme';

type Props = {
  text: string;
  size?: number;
  color?: string;
  /** 이 프레임부터 등장. 후킹 문구는 반드시 0으로 둔다. */
  from?: number;
  /** 어절당 지연 프레임. 크면 느려 보여서 이탈한다. 2~3 권장. */
  stagger?: number;
  align?: 'left' | 'center';
  weight?: number;
  lineHeight?: number;
  /** 첫 어절을 지연 없이 즉시 띄운다 (스와이프 이탈 방지용). */
  instantFirstWord?: boolean;
  style?: React.CSSProperties;
};

/**
 * 어절 단위로 튀어 오르는 큰 글씨.
 *
 * 통으로 페이드인 시키면 "읽을 게 없는 화면"이 0.3초 생기는데,
 * 스와이프 이탈은 바로 그 구간에서 난다. 그래서 어절을 쪼개
 * 계속 새 정보가 들어오는 것처럼 보이게 한다.
 */
export const BigText: React.FC<Props> = ({
  text,
  size = 92,
  color = c.text,
  from = 0,
  stagger = 2,
  align = 'left',
  weight = 400,
  lineHeight = 1.16,
  instantFirstWord = false,
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const words = text.split(' ');

  return (
    <div
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: `${size * 0.12}px ${size * 0.24}px`,
        justifyContent: align === 'center' ? 'center' : 'flex-start',
        fontFamily: font.head,
        fontSize: size,
        fontWeight: weight,
        color,
        lineHeight,
        letterSpacing: '-0.02em',
        textShadow: '0 6px 28px rgba(0,0,0,0.55)',
        ...style,
      }}
    >
      {words.map((w, i) => {
        const delay = instantFirstWord && i === 0 ? 0 : i * stagger;
        const p = spring({
          frame: frame - from - delay,
          fps,
          config: { damping: 200, mass: 0.45 },
        });
        return (
          <span
            key={`${w}-${i}`}
            style={{
              display: 'inline-block',
              opacity: p,
              transform: `translateY(${interpolate(p, [0, 1], [26, 0])}px) scale(${interpolate(
                p,
                [0, 1],
                [0.94, 1]
              )})`,
            }}
          >
            {w}
          </span>
        );
      })}
    </div>
  );
};
