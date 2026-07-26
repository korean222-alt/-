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

const CONTENT = join(process.cwd(), 'content');
const OUT = join(process.cwd(), 'out');
const FORCE = process.argv.includes('--force');

const TEMPLATES = new Set(['Ranking', 'ProblemSolve', 'Versus']);

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
      await render(template, props, dest);
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
