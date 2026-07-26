/**
 * 폰트를 public/fonts 로 미리 내려받는다.
 *
 * 렌더 중에 구글 폰트를 불러오면 (1) 자막 하나에 네트워크 요청이 수백 건
 * 붙고 (2) 네트워크가 흔들리는 순간 배치 렌더 전체가 죽는다.
 * 한 번 받아두고 @font-face로 로컬 파일을 물리는 게 훨씬 안정적이다.
 *
 *   node scripts/fetch-fonts.mjs
 */
import { mkdir, writeFile, access } from 'node:fs/promises';
import { join } from 'node:path';

const OUT = join(process.cwd(), 'public', 'fonts');

const FONTS = [
  { file: 'BlackHanSans-Regular.ttf', query: 'family=Black+Han+Sans' },
  { file: 'NotoSansKR-Regular.ttf', query: 'family=Noto+Sans+KR:wght@400', pick: 0 },
  { file: 'NotoSansKR-Bold.ttf', query: 'family=Noto+Sans+KR:wght@700', pick: 0 },
];

// UA를 안 보내면 구글이 subset woff2 대신 통짜 ttf를 내준다.
const CSS_HEADERS = { 'User-Agent': 'curl/8' };

const exists = async (p) => {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
};

const run = async () => {
  await mkdir(OUT, { recursive: true });

  for (const { file, query, pick = 0 } of FONTS) {
    const dest = join(OUT, file);
    if (await exists(dest)) {
      console.log(`skip  ${file} (이미 있음)`);
      continue;
    }

    const cssRes = await fetch(`https://fonts.googleapis.com/css2?${query}`, {
      headers: CSS_HEADERS,
    });
    if (!cssRes.ok) throw new Error(`css ${query}: HTTP ${cssRes.status}`);
    const css = await cssRes.text();

    const urls = [...css.matchAll(/https:\/\/[^)]+\.ttf/g)].map((m) => m[0]);
    if (!urls.length) throw new Error(`${file}: ttf URL을 못 찾음`);

    const res = await fetch(urls[pick]);
    if (!res.ok) throw new Error(`${file}: HTTP ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    await writeFile(dest, buf);
    console.log(`saved ${file}  ${(buf.length / 1024 / 1024).toFixed(1)}MB`);
  }

  console.log('\n폰트 준비 완료 → public/fonts');
};

run().catch((err) => {
  console.error('폰트 다운로드 실패:', err.message);
  process.exit(1);
});
