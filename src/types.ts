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

/**
 * 특가 한 건.
 *
 * 실사용 영상이 없으면 "좋은 물건이다"는 못 판다 — 그건 신뢰의 영역이고
 * 써본 사람을 못 이긴다. 대신 "지금 싸다"는 사실이라 신뢰가 필요 없다.
 * 그래서 파는 건 상품이 아니라 가격 낙차다.
 */
export type Deal = Product & {
  /**
   * 가격 이력을 묶는 키. 아무 문자열이나 쓰되 같은 상품엔 같은 값을 쓴다.
   * 이게 있으면 렌더할 때 역대 최저가인지 자동으로 판정된다.
   */
  id?: string;
  /** 할인 전 가격. price와의 낙차가 곧 콘텐츠다. */
  originalPrice: number;
  /**
   * "1롤당 575원" 같은 단가.
   *
   * 소모품 특가에서 제일 센 한 방이다. 6,900원은 비교 대상이 없어서
   * 싼지 모르겠는데, 1롤당 575원은 마트 가격이 머리에 있으니 즉시 판단된다.
   */
  unitLabel?: string | null;
  /**
   * 판매 페이지에 붙어 있는 배지. "최저가보상", "내일출발", "롤키친타올 1위" 등.
   * 실사용 후기를 대신하는 근거라서 **있는 그대로만** 옮겨 적는다.
   */
  badges?: string[] | null;
  freeShipping?: boolean | null;
  /** 실사용 후기를 대신하는 객관 지표. 있으면 넣는다. */
  rating?: number | null;
  reviewCount?: number | null;
  /** 가격 이력을 쌓기 시작하면 채운다. 이게 붙으면 설득력이 완전히 달라진다. */
  lowestEver?: boolean | null;
};

export type DealProps = {
  /** 비우면 최대 할인율로 자동 생성된다. */
  hook?: string | null;
  /** "오늘 자정까지" 같은 마감. 긴급성이 클릭을 만든다. */
  deadline?: string | null;
  /**
   * 가격을 확인한 시점. 필수다.
   *
   * 특가는 몇 시간이면 끝난다. 올린 뒤 가격이 올라가 있으면 신뢰가 한 번에
   * 무너지고 허위 표시 문제도 생긴다. 시점을 화면에 박아두는 게 유일한 방어다.
   */
  priceCheckedAt: string;
  items: Deal[];
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
