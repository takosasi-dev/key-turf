// 全部の画面を 5 つの大きさで撮る(UI の作り直しの前後を見比べる用。作りは KeySwat の tests/web/shots.mjs)。
// Chrome 1 回の起動で、画面ごとに窓の大きさだけ替えて撮る。遊びの画面は「ふたりで」を決まった道で動かす。
//     node tests/web/shots.mjs before     → build/web_shots/before/<画面>_<幅>x<高さ>.png
//     node tests/web/shots.mjs after
//     node tests/web/shots.mjs after --docs   README の画像 3 枚(タイトル・遊び・結果の 1280×720。入りの動きが終わってから撮った物)を docs/ に写す
// スマホ(390×844)は「記録だけ」(落ちない・字が読める、を見る)。
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { open, OUT, ROOT, SAVE_KEY, serve, sleep } from './lib.mjs';

const PHASE = process.argv[2] || 'after';
const DIR = path.join(OUT, PHASE);
mkdirSync(DIR, { recursive: true });
const SIZES = [[1280, 720], [1920, 1080], [1024, 768], [2560, 1080], [390, 844]];
const W = 48;
const KEYS = [['w', 'd', 's', 'a'], ['ArrowUp', 'ArrowRight', 'ArrowDown', 'ArrowLeft']];
const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const xy = (i) => [i % W, Math.floor(i / W)];
const dist = (a, b) => { const [ax, ay] = xy(a), [bx, by] = xy(b); return Math.abs(ax - bx) + Math.abs(ay - by); };

async function shootAll(name, settle = 250) {
	for (const [w, h] of SIZES) {
		await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false });
		await sleep(settle);
		const data = (await page.cdp.send('Page.captureScreenshot', { format: 'png' })).data;
		writeFileSync(path.join(DIR, `${name}_${w}x${h}.png`), Buffer.from(data, 'base64'));
	}
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
	await sleep(150);
}

// 決まった道を走らせる(check.mjs の drive を短くした物)。at(pl) が真になった時に一時停止して全部の大きさで撮り、続ける。
async function drive(segs, name = null, at = null) {
	let s = await page.waitState((st) => st.play && st.play.phase === 0 && st.play.wait < 0, 10000);
	if (!s) return null;
	const st = [0, 1].map((p) => ({ i: 0, moved: 0, head: s.play.heads[p] }));
	for (const p of [0, 1]) if (segs[p][0][0] !== s.play.dirs[p]) await page.key(KEYS[p][segs[p][0][0]]);
	for (const end = Date.now() + 60000; Date.now() < end;) {
		s = await page.state();
		const pl = s.play;
		if (!pl) return null;
		if (name && at(pl)) {
			await shootAll(name, 300);
			name = null;
		}
		if (pl.wait >= 0) return pl;
		for (const p of [0, 1]) {
			const k = st[p];
			if (pl.heads[p] === k.head) continue;
			k.moved += dist(pl.heads[p], k.head);
			k.head = pl.heads[p];
			const seg = segs[p][k.i];
			if (seg && k.moved >= seg[1] && k.i + 1 < segs[p].length) {
				k.i += 1;
				k.moved = 0;
				await page.key(KEYS[p][segs[p][k.i][0]]);
			}
		}
		await sleep(10);
	}
	return null;
}

const CIRCLE = Array.from({ length: 10 }, () => [[1, 1], [2, 1], [3, 1], [0, 1]]).flat();
const ROUNDS = {
	cut: [[[1, 20], [0, 99]], [[0, 8], [3, 99]]],
	self: [[[1, 5], [0, 3], [3, 2], [2, 9]], [[3, 99]]],
	headon: [[[1, 99]], [[2, 1], [3, 99]]],
	enclose: [[[2, 1], ...CIRCLE, [1, 1], [0, 6], [1, 6], [2, 8], [3, 6], [0, 99]], [[0, 10], [3, 37], [2, 11], [1, 99]]],
};

try {
	console.log(`起動 ${page.bootMs} ms`);
	await page.waitState((s) => s.screen === 'gate', 30000);
	console.log(`S0 まで ${Date.now() - page.t0} ms`);
	await page.evaluate(`localStorage.setItem('${SAVE_KEY}', JSON.stringify({version: 1, vs_cpu: {easy: {win: 3, lose: 5, draw: 0}, normal: {win: 1, lose: 4, draw: 1}},
		settings: {volume: 75, shake: true, reduce_flash: false}}))`);
	await sleep(400);
	await shootAll('s0');
	await page.goto(page.url0); // 記録を読ませ直す
	await page.waitState((s) => s.screen === 'gate', 30000);
	await page.key('x');
	await page.waitState((s) => s.screen === 'title');
	await sleep(900);
	await shootAll('s1_title', 400);
	for (const k of ['ArrowDown', 'ArrowDown', 'ArrowDown', 'Enter']) await page.key(k);
	await page.waitState((s) => s.screen === 'settings');
	await sleep(600);
	await shootAll('s4_settings');
	for (const k of ['ArrowDown', 'ArrowDown', 'ArrowDown', 'Enter']) await page.key(k);
	await sleep(200);
	for (const k of ['w', 'd', 'ArrowUp']) await page.down(k);
	await sleep(200);
	await shootAll('s4_keytest');
	for (const k of ['w', 'd', 'ArrowUp']) await page.up(k);
	await page.key('Escape');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title');
	await sleep(300);
	// ふたりで → 練習(数え・大きく囲んだ後の中盤)
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'play' && s.play?.practice, 5000);
	const practice = [[[1, 12], [0, 8], [3, 11], [2, 6]], [[3, 4], [2, 4], [1, 4], [0, 2]]];
	await drive(practice, 's2_play', (pl) => pl.counts[0] > 100 && pl.counts[1] > 30);
	await sleep(300);
	await shootAll('s2_band', 120);
	for (const name of ['cut', 'self', 'headon', 'enclose', 'cut']) await drive(ROUNDS[name]);
	await page.waitState((s) => s.screen === 'result', 8000);
	await sleep(1400);
	await shootAll('s3_result', 300);
	await page.key('r');
	await page.waitState((s) => s.screen === 'play' && s.play?.phase === 0, 8000);
	await sleep(300);
	await shootAll('s2_count', 100);
	await page.waitState((s) => s.play?.phase === 1, 8000);
	await sleep(1500);
	await page.key('Escape');
	await page.waitState((s) => s.paused, 3000);
	await sleep(500);
	await shootAll('s5_pause');
	for (const k of ['ArrowDown', 'ArrowDown', 'ArrowDown', 'Enter']) await page.key(k);
	await page.waitState((s) => s.screen === 'title', 3000);
	const base = page.url0.split('?')[0];
	await page.goto(base + '?keys=1&debug=1');
	await page.waitState((s) => s.screen === 'gate', 20000);
	await page.key('x');
	await page.waitState((s) => s.screen === 'keys', 3000);
	for (const c of ['w', 'a', 'ArrowUp', 'ArrowLeft']) { await page.key(c); await sleep(30); }
	await sleep(300);
	await shootAll('keys');
	console.log(`コンソールのエラー ${page.errors().length} 件(読み込み中の画面を撮る前まで)`);
	for (const e of page.errors()) console.log('  ' + e.text);
	// 読み込み中の画面(index.wasm を止めて、Godot が立ち上がる前の画面のまま撮る)
	await page.cdp.send('Network.setBlockedURLs', { urls: ['*index.wasm*'] });
	await page.cdp.send('Page.navigate', { url: base });
	await sleep(2500);
	await shootAll('loading', 200);
} finally {
	await page.close();
	site.stop();
}
if (process.argv.includes('--docs')) {
	for (const [from, to] of [['s1_title', 'title'], ['s2_play', 'play'], ['s3_result', 'result']]) {
		copyFileSync(path.join(DIR, `${from}_1280x720.png`), path.join(ROOT, 'docs', `${to}.png`));
	}
}
