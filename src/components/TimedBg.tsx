import React from 'react';
import { interpolateColors, useCurrentFrame } from 'remotion';
import { Bg } from './Bg';

export type BgSegment = { from: number; tint: string };

/**
 * 구간별로 배경색이 흐르듯 바뀐다.
 *
 * 장면마다 배경을 따로 두면 전환 순간에 색이 툭 끊긴다.
 * 배경 하나를 두고 색만 보간하면 끊김 없이 넘어가면서도
 * "화면이 계속 변하고 있다"는 느낌이 유지된다.
 */
export const TimedBg: React.FC<{ segments: BgSegment[]; blend?: number }> = ({
  segments,
  blend = 18,
}) => {
  const frame = useCurrentFrame();

  if (segments.length === 0) return <Bg />;
  if (segments.length === 1) return <Bg tint={segments[0].tint} />;

  // 각 구간 시작 지점 앞뒤로 blend 프레임에 걸쳐 색을 섞는다.
  const stops: number[] = [];
  const colors: string[] = [];
  segments.forEach((seg, i) => {
    if (i === 0) {
      stops.push(0);
      colors.push(seg.tint);
      return;
    }
    stops.push(seg.from - blend / 2, seg.from + blend / 2);
    colors.push(segments[i - 1].tint, seg.tint);
  });

  const tint = interpolateColors(frame, stops, colors);
  return <Bg tint={tint} />;
};
