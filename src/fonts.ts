import { staticFile, continueRender, delayRender } from 'remotion';

/**
 * public/fonts 에 받아둔 파일을 등록한다.
 * 파일이 없으면 `npm run fonts` 를 한 번 돌리면 된다.
 *
 * 렌더 중에 구글 폰트를 부르지 않는 이유는 scripts/fetch-fonts.mjs 주석 참고.
 */
const FACES: [family: string, file: string, weight: string][] = [
  ['Black Han Sans', 'fonts/BlackHanSans-Regular.ttf', '400'],
  ['Noto Sans KR', 'fonts/NotoSansKR-Regular.ttf', '400'],
  ['Noto Sans KR', 'fonts/NotoSansKR-Bold.ttf', '700'],
];

let done = false;

export const ensureFonts = () => {
  if (done || typeof document === 'undefined') return;
  done = true;

  // 폰트가 깔리기 전에 프레임을 캡처하면 그 컷만 시스템 폰트로 찍힌다.
  // 하필 그게 썸네일이 되면 손해라서 전부 로딩될 때까지 렌더를 붙잡는다.
  const handle = delayRender('한글 폰트 로딩');

  Promise.all(
    FACES.map(async ([family, file, weight]) => {
      const face = new FontFace(family, `url(${staticFile(file)})`, { weight });
      await face.load();
      // FontFaceSet.add 는 tsconfig의 DOM lib 버전에 따라 타입이 빠져 있다.
      (document.fonts as unknown as { add(f: FontFace): void }).add(face);
    })
  )
    .catch((err) => {
      console.warn('[fonts] 로컬 폰트 로딩 실패 — `npm run fonts` 를 실행했나요?', err);
    })
    .finally(() => continueRender(handle));
};
