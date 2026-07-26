import { Config } from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');

/**
 * 한글 폰트는 통짜 TTF라 파일 하나가 6MB쯤 된다. 렌더 탭이 여러 개 뜨면
 * 그걸 동시에 파싱하느라 기본 타임아웃(30초)을 넘겨서 렌더가 죽는다.
 * 여유를 주고 동시 탭 수를 줄이면 안정적으로 끝난다.
 */
Config.setDelayRenderTimeoutInMilliseconds(120_000);
Config.setConcurrency(2);

// 이 컨테이너에는 Playwright용 크로미움이 이미 깔려 있다.
// 없으면 Remotion이 매번 따로 받으니 있는 걸 그대로 쓴다.
if (process.env.REMOTION_BROWSER) {
  Config.setBrowserExecutable(process.env.REMOTION_BROWSER);
}
