// 公開した物を、?debug=1 に頼らずに開いて確かめる(起動の秒数・コンソールのエラー・S0 と S1 と練習の画面)。
//     KT_URL=https://takosasi-dev.github.io/key-turf/ node tests/web/boot.mjs [名前の頭]
import { expect, failureCount, open, serve, sleep } from './lib.mjs';

const prefix = process.argv[2] || 'pub';
const site = serve();
const page = await open(site.url);
try {
	expect(page.booted, `起動した(Godot の印字まで ${page.bootMs} ms)`);
	await sleep(4000);
	await page.shot(`${prefix}_s0`);
	await page.key('x');
	await sleep(800);
	await page.shot(`${prefix}_s1`);
	await page.key('Enter');
	await sleep(3000);
	await page.shot(`${prefix}_s2`);
	await page.key('Escape');
	await sleep(500);
	await page.shot(`${prefix}_s5`);
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).slice(0, 5).join(' / ') : ''));
	console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));
} finally {
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? '全部 OK' : `${failureCount()} 件 NG`);
process.exit(failureCount() === 0 ? 0 : 1);
