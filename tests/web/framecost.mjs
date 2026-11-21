// 画面ごとの 1 フレームの重さ(窓なし Chrome のソフト描画。requestAnimationFrame の間隔の中央値)を測る。前後の版を比べる用。
//     node tests/web/framecost.mjs
//     KT_WEB=build/web_v020 node tests/web/framecost.mjs
import { open, serve, sleep } from './lib.mjs';

const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const measure = async (label) => {
	const v = await page.evaluate(`new Promise((ok) => { const t = []; let last = performance.now(); const end = last + 3000;
		const f = (now) => { t.push(now - last); last = now; if (now < end) requestAnimationFrame(f); else { t.sort((a, b) => a - b); ok([t.length, t[t.length >> 1], t[Math.floor(t.length * 0.95)]]); } };
		requestAnimationFrame(f); })`);
	console.log(`${label}: ${v[0]} 回・中央値 ${v[1].toFixed(1)} ms・95% ${v[2].toFixed(1)} ms`);
};
// 画面に着かなかったら止める(着かないまま測ると、Godot の動いていないページの軽い数字が出る)
const reach = async (pred, label, ms) => { if (!(await page.waitState(pred, ms))) throw new Error(`${label} に着かない(版 ${(await page.state()).version})`); };
try {
	await reach((s) => s.screen === 'gate', 'S0', 30000);
	console.log(`版 ${(await page.state()).version}`);
	await sleep(1000);
	await measure('S0');
	await page.key('x');
	await reach((s) => s.screen === 'title', 'タイトル', 15000);
	await sleep(1000);
	await measure('タイトル');
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await reach((s) => s.play?.phase === 1, '遊び', 8000);
	await measure('遊び(練習)');
} finally {
	await page.close();
	site.stop();
}
