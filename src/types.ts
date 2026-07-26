/**
 * 상품 한 건. 지금은 손으로 채우고, 쿠팡 오픈API가 열리면
 * (누적 판매 15만원 이후) 같은 모양으로 자동 생성해서 갈아끼운다.
 */
export type Product = {
  /** 화면에 뜨는 짧은 이름. 12자 넘으면 두 줄로 깨지니 줄여 쓴다. */
  name: string;
  /** 왜 사야 하는지 한 줄. 스펙 말고 "체감"으로 쓴다. */
  punch: string;
  /** 원. 카운트업 애니메이션으로 올라간다. */
  price: number;
  /** 상품 이미지 URL. 없으면 emoji + 그라데이션 카드로 대체된다. */
  image?: string;
  /** image가 없을 때 쓰는 대체 그림. */
  emoji?: string;
  /** 카드 색조. 없으면 순위별 기본색. */
  tint?: string;
};

export type RankingProps = {
  /** 0프레임에 바로 뜨는 후킹. 이게 조회수의 90%다. */
  hook: string;
  /** 후킹 아래 작게 깔리는 보조 문구. */
  subHook?: string;
  /** 1위가 마지막에 오도록 자동 역순 정렬된다. 배열은 1위부터 넣는다. */
  items: Product[];
  /** 마지막 CTA. */
  cta: string;
};

export type ProblemSolveProps = {
  /** 0프레임 문제 제시. "이거 나잖아" 소리 나오게. */
  problem: string;
  /** 문제를 굳히는 한 줄. */
  problemDetail?: string;
  items: Product[];
  cta: string;
};

export type VersusProps = {
  hook: string;
  left: Product;
  right: Product;
  /** 결론 문구. */
  verdict: string;
  cta: string;
};
