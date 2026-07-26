import React, { createContext, useContext } from 'react';

/**
 * 밝은 테마 / 어두운 테마.
 *
 * 처음엔 어두운 네온으로 만들었는데, 한국에서 그 조합(검은 배경 + 형광
 * 민트·핑크)은 도박·코인 광고의 시각 언어다. 스크롤하다 보면 "광고"로
 * 먼저 읽힌다.
 *
 * 반면 토스·쿠팡·네이버쇼핑은 전부 흰 배경에 검정 글씨다. 커머스에서
 * 신뢰를 만드는 건 밝은 화면이고, 밝으면 "정보"로 읽힌다. 실사용 영상이
 * 없어 이미 신뢰가 부족한 판이라 이 차이가 크다.
 *
 * 다만 어느 쪽이 실제로 이길지는 추측이라 둘 다 남겨두고 골라 쓴다.
 */
export type Palette = {
  mode: 'light' | 'dark';
  bg: string;
  bgDeep: string;
  surface: string;
  surfaceHi: string;
  line: string;
  text: string;
  textDim: string;
  /** 할인·마감 등 "빨간 신호" 자리 */
  hot: string;
  amber: string;
  accent: string;
  mint: string;
  gold: string;
  /** 가격 강조 기본색. 밝은 테마에서는 커머스 관행대로 빨강이다. */
  price: string;
};

export const darkPalette: Palette = {
  mode: 'dark',
  bg: '#0E0B14',
  bgDeep: '#07050B',
  surface: '#1A1522',
  surfaceHi: '#241D30',
  line: 'rgba(255,255,255,0.10)',
  text: '#FFFFFF',
  textDim: '#A99CBD',
  hot: '#FF6B9D',
  amber: '#FFC46B',
  accent: '#8B6BFF',
  mint: '#5EE6C0',
  gold: '#FFD666',
  price: '#5EE6C0',
};

/** 토스·쿠팡이 쓰는 계열. 회색은 차갑게, 빨강은 가격에만. */
export const lightPalette: Palette = {
  mode: 'light',
  bg: '#FFFFFF',
  bgDeep: '#FFFFFF',
  surface: '#F2F4F6',
  surfaceHi: '#E9ECEF',
  line: 'rgba(0,0,0,0.09)',
  text: '#191F28',
  textDim: '#6B7684',
  hot: '#F04452',
  amber: '#FF8A00',
  accent: '#3182F6',
  mint: '#00B876',
  gold: '#FFB800',
  price: '#F04452',
};

const PaletteContext = createContext<Palette>(darkPalette);

export const usePalette = () => useContext(PaletteContext);

export const PaletteProvider: React.FC<{
  theme?: 'light' | 'dark' | null;
  children: React.ReactNode;
}> = ({ theme, children }) => (
  <PaletteContext.Provider value={theme === 'light' ? lightPalette : darkPalette}>
    {children}
  </PaletteContext.Provider>
);
