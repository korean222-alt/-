import React from 'react';
import { c, font } from '../theme';

/**
 * 대가성 표기. 빼면 안 된다.
 *
 * 공정위 추천·보증 심사지침상 제휴 수수료를 받는 콘텐츠는 그 사실을
 * 소비자가 쉽게 인식할 수 있게 표시해야 한다. 쿠팡파트너스 약관에도
 * 같은 의무가 있고, 누락은 활동 정지 사유다.
 * 영상 전 구간에 계속 떠 있게 두는 게 가장 안전하다.
 */
export const Disclosure: React.FC<{ text?: string }> = ({
  text = '이 영상은 파트너스 활동의 일환으로 수수료를 받을 수 있습니다',
}) => (
  <div
    style={{
      fontFamily: font.body,
      fontSize: 24,
      fontWeight: 500,
      color: c.textDim,
      background: 'rgba(0,0,0,0.42)',
      border: `1px solid ${c.line}`,
      borderRadius: 10,
      padding: '8px 16px',
      alignSelf: 'flex-start',
      letterSpacing: '-0.01em',
    }}
  >
    {text}
  </div>
);
