/**
 * 가격 이력. 이 프로젝트에서 유일하게 시간이 지날수록 강해지는 부분이다.
 *
 * "이거 싸요"는 누구나 한다. "역대 최저가예요"는 가격을 계속 기록한
 * 사람만 할 수 있다. 실사용 영상을 가진 사람도 이건 못 한다 —
 * 물건을 써본다고 지난 6개월 가격을 아는 건 아니니까.
 *
 *   node scripts/price-history.mjs add 데스크패드-대형 9900
 *   node scripts/price-history.mjs check 데스크패드-대형 9900
 *   node scripts/price-history.mjs list 데스크패드-대형
 *
 * 오늘 기록을 시작하면 3개월 뒤엔 남이 못 따라오는 무기가 된다.
 * 지금은 손으로 넣지만, 쿠팡 오픈API가 열리면 그대로 자동화하면 된다.
 */
import { appendFile, readFile, mkdir, access } from 'node:fs/promises';
import { dirname, join } from 'node:path';

const FILE = join(process.cwd(), 'data', 'price-history.jsonl');

const exists = async (p) => {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
};

/** 한 상품의 기록 전체를 시간순으로 읽는다. */
export const readHistory = async (id) => {
  if (!(await exists(FILE))) return [];
  const text = await readFile(FILE, 'utf8');
  return text
    .split('\n')
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null; // 손으로 편집하다 깨진 줄은 조용히 건너뛴다
      }
    })
    .filter((row) => row && row.id === id);
};

export const addPrice = async (id, price, at = new Date().toISOString()) => {
  await mkdir(dirname(FILE), { recursive: true });
  await appendFile(FILE, JSON.stringify({ id, price, at }) + '\n', 'utf8');
};

/**
 * 역대 최저가인지 판정한다.
 *
 * 기록이 2건 미만이면 최저가라고 말하지 않는다. 어제 한 번 본 게 전부인데
 * "역대 최저"라고 하는 건 거짓말이고, 그 한 번이 채널 신뢰를 끝낸다.
 */
export const isLowestEver = async (id, price, minSamples = 3) => {
  const rows = await readHistory(id);
  if (rows.length < minSamples) return false;
  return price <= Math.min(...rows.map((r) => r.price));
};

const main = async () => {
  const [cmd, id, priceArg] = process.argv.slice(2);
  const price = Number(priceArg);

  if (cmd === 'add') {
    if (!id || !Number.isFinite(price)) {
      console.error('사용법: node scripts/price-history.mjs add <id> <가격>');
      process.exit(1);
    }
    await addPrice(id, price);
    const rows = await readHistory(id);
    const low = Math.min(...rows.map((r) => r.price));
    console.log(`기록 완료  ${id}  ${price.toLocaleString('ko-KR')}원`);
    console.log(`  누적 ${rows.length}건 · 역대 최저 ${low.toLocaleString('ko-KR')}원`);
    return;
  }

  if (cmd === 'check') {
    if (!id || !Number.isFinite(price)) {
      console.error('사용법: node scripts/price-history.mjs check <id> <가격>');
      process.exit(1);
    }
    const rows = await readHistory(id);
    const lowest = await isLowestEver(id, price);
    console.log(`${id}  누적 ${rows.length}건`);
    if (rows.length < 3) {
      console.log('  기록이 3건 미만이라 "역대 최저가"는 아직 붙일 수 없습니다.');
    } else {
      console.log(
        lowest
          ? '  역대 최저가입니다 — lowestEver 배지가 붙습니다.'
          : `  최저가는 ${Math.min(...rows.map((r) => r.price)).toLocaleString('ko-KR')}원입니다.`
      );
    }
    return;
  }

  if (cmd === 'list') {
    const rows = await readHistory(id);
    if (rows.length === 0) {
      console.log('기록 없음');
      return;
    }
    for (const r of rows) {
      console.log(`${r.at.slice(0, 16).replace('T', ' ')}  ${r.price.toLocaleString('ko-KR')}원`);
    }
    return;
  }

  console.log('명령: add / check / list');
  process.exit(1);
};

// 스크립트로 직접 실행했을 때만 CLI로 동작한다 (import 시에는 조용히)
if (process.argv[1] && process.argv[1].endsWith('price-history.mjs')) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
