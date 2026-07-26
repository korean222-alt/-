export const FPS = 30;
export const W = 1080;
export const H = 1920;

/** 초 → 프레임 */
export const s = (sec: number) => Math.round(sec * FPS);

/**
 * 쇼츠 UI 안전영역.
 * 유튜브/릴스는 하단(제목·채널명·음원)과 우측(좋아요·댓글·공유)에
 * 자기 UI를 덮어씌운다. 여기에 글자를 두면 가려져서 안 읽힌다.
 */
export const SAFE = {
  top: 210,
  bottom: 430,
  left: 72,
  right: 150,
};

export const CONTENT_W = W - SAFE.left - SAFE.right;

export const c = {
  bg: '#0E0B14',
  bgDeep: '#07050B',
  surface: '#1A1522',
  surfaceHi: '#241D30',
  line: 'rgba(255,255,255,0.10)',

  text: '#FFFFFF',
  textDim: '#A99CBD',

  pink: '#FF6B9D',
  amber: '#FFC46B',
  violet: '#8B6BFF',
  mint: '#5EE6C0',
  gold: '#FFD666',
};

/** 순위별 색. 1위로 갈수록 뜨거워진다. */
export const rankTint = (rank: number) =>
  ({ 1: c.gold, 2: c.pink, 3: c.violet, 4: c.mint, 5: '#6BA8FF' } as Record<
    number,
    string
  >)[rank] ?? c.violet;

export const font = {
  head: '"Black Han Sans", "Noto Sans KR", system-ui, sans-serif',
  body: '"Noto Sans KR", system-ui, sans-serif',
};

export const won = (n: number) => n.toLocaleString('ko-KR');

/**
 * 색에 투명도를 입힌다.
 *
 * `${color}CC` 같은 문자열 이어붙이기를 쓰면 안 된다. interpolateColors가
 * 돌려주는 값은 `rgba(...)` 문자열이라 뒤에 16진수를 붙이는 순간 CSS가
 * 그 선언 전체를 버린다 — 배경이 통째로 사라진다.
 */
export const alpha = (color: string, a: number): string => {
  const hex = color.trim();

  if (hex.startsWith('#')) {
    const h = hex.slice(1);
    const full =
      h.length === 3
        ? h
            .split('')
            .map((ch) => ch + ch)
            .join('')
        : h.slice(0, 6);
    const n = parseInt(full, 16);
    return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
  }

  const nums = hex.match(/[\d.]+/g);
  if (nums && nums.length >= 3) {
    return `rgba(${nums[0]}, ${nums[1]}, ${nums[2]}, ${a})`;
  }
  return hex;
};
