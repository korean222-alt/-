/**
 * content/*.json 을 전부 읽어서 영상으로 뽑는다.
 *
 *   node scripts/render-batch.mjs            # 아직 안 만든 것만
 *   node scripts/render-batch.mjs --force    # 전부 다시
 *
 * 이 프로젝트의 존재 이유가 이 스크립트다. 하루 1개 만들 걸 하루 10개
 * 만들게 해주는 부분이고, 나머지 코드는 전부 이걸 돌리기 위한 재료다.
 *
 * JSON 한 건이 영상 한 편이다:
 *   { "template": "Ranking", "slug": "desk-top5", "hook": "...", "items": [...] }
 */
import { readdir, readFile, mkdir, access, writeFile, rm } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { addPrice, readHistory, isLowestEver } from './price-history.mjs';

const CONTENT = join(process.cwd(), 'content');
const OUT = join(process.cwd(), 'out');
const FORCE = process.argv.includes('--force');

const TEMPLATES = new Set(['Ranking', 'ProblemSolve', 'Versus', 'Deal']);

const exists = async (p) => {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
};

const render = async (composition, props, dest) => {
  // props를 CLI 인자에 직접 박으면 한글·따옴표가 셸에서 깨진다.
  // 임시 파일로 넘기면 이스케이프를 신경 쓸 필요가 없다.
  const propsFile = join(tmpdir(), `shorts-props-${randomUUID()}.json`);
  await writeFile(propsFile, JSON.stringify(props), 'utf8');

  try {
    await new Promise((resolve, reject) => {
      const child = spawn(
        'npx',
        ['remotion', 'render', composition, dest, `--props=${propsFile}`, '--log=error'],
        { stdio: 'inherit' }
      );
      child.on('error', reject);
      child.on('close', (code) =>
        code === 0 ? resolve() : reject(new Error(`렌더 실패 (exit ${code})`))
      );
    });
  } finally {
    await rm(propsFile, { force: true });
  }
};

/**
 * 안 넣은 필드를 null로 명시해서 넘긴다.
 *
 * Remotion은 컴포지션의 defaultProps와 --props를 병합한다. 그래서 JSON에
 * 빠진 필드는 조용히 defaultProps 값으로 채워진다 — 마감 시한을 안 적었는데
 * 다른 상품의 "오늘 자정까지"가 화면에 뜨는 식이다. 없는 마감을 지어내는
 * 허위 표시가 되므로, 빠진 건 전부 null로 못 박아 기본값을 덮는다.
 */
const NULLABLE_DEAL_FIELDS = ['hook', 'deadline', 'theme', 'narration'];
const NULLABLE_ITEM_FIELDS = [
  'unitLabel',
  'badges',
  'freeShipping',
  'rating',
  'reviewCount',
  'lowestEver',
  'stockWarning',
  'image',
  'emoji',
  'tint',
  'punch',
];

const fillNulls = (obj, fields) => {
  const out = { ...obj };
  for (const f of fields) if (out[f] === undefined) out[f] = null;
  return out;
};

/**
 * 특가 영상은 렌더할 때 가격을 자동으로 기록하고, 역대 최저가면 배지를 붙인다.
 *
 * 영상을 만들 때마다 데이터가 쌓이는 구조라, 따로 관리할 필요가 없다.
 * `id`를 안 넣은 상품은 그냥 지나간다 — 기록할 키가 없으니 판정도 못 한다.
 */
const enrichDeals = async (items) =>
  Promise.all(
    items.map(async (item) => {
      if (!item.id) return item;

      // 같은 날 같은 가격을 여러 번 기록하면 이력이 오염된다 (--force 재렌더 등)
      const today = new Date().toISOString().slice(0, 10);
      const rows = await readHistory(item.id);
      const dupe = rows.some(
        (r) => r.price === item.price && r.at.slice(0, 10) === today
      );
      if (!dupe) await addPrice(item.id, item.price);

      const lowest = await isLowestEver(item.id, item.price);
      if (lowest) console.log(`  ★ ${item.name}: 역대 최저가`);
      return { ...item, lowestEver: lowest };
    })
  );

const prepareDeal = async (props) => {
  const items = await enrichDeals(props.items);
  return {
    ...fillNulls(props, NULLABLE_DEAL_FIELDS),
    items: items.map((it) => fillNulls(it, NULLABLE_ITEM_FIELDS)),
  };
};

const run = async () => {
  if (!(await exists(CONTENT))) {
    console.error(`content/ 폴더가 없습니다. JSON을 거기 넣으세요.`);
    process.exit(1);
  }
  await mkdir(OUT, { recursive: true });

  const files = (await readdir(CONTENT)).filter((f) => f.endsWith('.json')).sort();
  if (files.length === 0) {
    console.log('content/ 에 JSON이 없습니다.');
    return;
  }

  let ok = 0;
  const failed = [];

  for (const file of files) {
    const raw = JSON.parse(await readFile(join(CONTENT, file), 'utf8'));
    const { template, slug, ...props } = raw;

    if (!TEMPLATES.has(template)) {
      console.error(`✗ ${file}: template이 ${[...TEMPLATES].join('/')} 중 하나여야 합니다`);
      failed.push(file);
      continue;
    }

    const name = slug ?? file.replace(/\.json$/, '');
    const dest = join(OUT, `${name}.mp4`);

    if (!FORCE && (await exists(dest))) {
      console.log(`skip  ${name}.mp4 (이미 있음 — 다시 만들려면 --force)`);
      continue;
    }

    const started = Date.now();
    console.log(`\n▶ ${name}  (${template})`);
    try {
      const finalProps = template === 'Deal' ? await prepareDeal(props) : props;
      await render(template, finalProps, dest);
      console.log(`✓ ${name}.mp4  ${((Date.now() - started) / 1000).toFixed(0)}초`);
      ok++;
    } catch (err) {
      console.error(`✗ ${name}: ${err.message}`);
      failed.push(file);
    }
  }

  console.log(`\n완료: ${ok}개 성공${failed.length ? `, ${failed.length}개 실패` : ''}`);
  if (failed.length) {
    console.log('실패:', failed.join(', '));
    process.exit(1);
  }
};

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
