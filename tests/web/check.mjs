// Web 版をまとめて確かめ、画面を撮る(Chrome 1 回の起動で済ませる。build/web_shots/ に PNG)。
// S0 → S1 → S4(キーの確かめで 2 人の同時押し)→ ふたりで(練習 → 決まった道で 5 ラウンド: 線を切った・自分の線・正面衝突・囲んだ・線を切った)→ S3 →
// もう1回(R)→ S5 → タイトル → 揺れ 切・点滅を弱める 入 の決着 → タブが裏で一時停止 → 保存と通信 0 件(AC-22)。
// キーは本物のキー(CDP の Input.dispatchKeyEvent)。状態は ?debug=1 の window.ktState を読むだけ。
//     node tests/web/check.mjs            手元の build/web を配って確かめる
//     KT_URL=https://…/key-turf/ node tests/web/check.mjs   公開した物を確かめる
//     node tests/web/check.mjs --cpu      CPU と(やさしい)を JS の bot で 1 試合(AC-19 のブラウザ分。別の起動にした)
import { expect, failureCount, open, serve, sleep } from './lib.mjs';

const CPU = process.argv.includes('--cpu');
const W = 48;
const KEYS = [['w', 'd', 's', 'a'], ['ArrowUp', 'ArrowRight', 'ArrowDown', 'ArrowLeft']]; // 人ごとの 上・右・下・左
const STEP = [[0, -1], [1, 0], [0, 1], [-1, 0]];
const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const shot = (label) => page.shot(label);
const play = async () => (await page.state()).play;
const xy = (i) => [i % W, Math.floor(i / W)];
const dist = (a, b) => { const [ax, ay] = xy(a), [bx, by] = xy(b); return Math.abs(ax - bx) + Math.abs(ay - by); };

// 決着の演出を続けて撮る(出来事から 0〜1.2 秒)
async function burst(prefix, times = [0, 150, 350, 650, 1100]) {
	const t0 = Date.now();
	for (const t of times) {
		const wait = t0 + t - Date.now();
		if (wait > 0) await sleep(wait);
		await shot(`${prefix}_${t}`);
	}
}

// 決まった道を走らせる。segs[p] = [[向き, マス数], ...](最後のマス数が尽きたら真っすぐ)。最初の向きは数えの間に予約する(FR-16)。
// 頭のマスが変わったのを見て次の向きを押す(窓なし Chrome が遅くても時機がずれない)。ラウンドが終わったら決着を撮って返す。
async function drive(segs, label, onCapture = null, goShot = null) {
	let s = await page.waitState((st) => st.play && st.play.phase === 0 && st.play.wait < 0, 10000);
	if (!s) return null;
	const st = [0, 1].map((p) => ({ i: 0, moved: 0, head: s.play.heads[p] }));
	for (const p of [0, 1]) {
		if (segs[p] && segs[p][0][0] !== s.play.dirs[p]) await page.key(KEYS[p][segs[p][0][0]]);
	}
	let counts = s.play.counts.slice();
	for (const end = Date.now() + 60000; Date.now() < end;) {
		s = await page.state();
		const pl = s.play;
		if (!pl) return null;
		if (goShot && pl.phase === 1) {
			await shot(goShot);
			goShot = null;
		}
		if (pl.wait >= 0) {
			await burst(label);
			return pl;
		}
		for (const p of [0, 1]) {
			const k = st[p];
			if (pl.heads[p] === k.head) continue;
			k.moved += dist(pl.heads[p], k.head);
			k.head = pl.heads[p];
			const seg = segs[p]?.[k.i];
			if (seg && k.moved >= seg[1] && k.i + 1 < segs[p].length) {
				k.i += 1;
				k.moved = 0;
				await page.key(KEYS[p][segs[p][k.i][0]]);
			}
		}
		for (const p of [0, 1]) {
			if (pl.counts[p] > counts[p] + 3 && onCapture) await onCapture(p, pl.counts[p] - counts[p]);
		}
		counts = pl.counts.slice();
		await sleep(10);
	}
	return null;
}

// CPU との試合の P1 の bot(CPU の作りを JS で真似る): 陣地の中で計画(空いた向きへ a マス・直角へ b マス)、超えたら陣地への最短の道で戻る。
function botTurn(pl, rnd) {
	const p = 0, head = pl.heads[p], [hx, hy] = xy(head), dir = pl.dirs[p];
	const own = (i) => pl.owner[i] === p + 1, mine = (i) => pl.trail[i] === p + 1;
	const inBoard = (x, y) => x >= 0 && y >= 0 && x < W && y < 26;
	const trailLen = pl.trail.filter((v) => v === p + 1).length;
	if (own(head) && trailLen === 0 && (!botTurn.plan || botTurn.plan.left)) {
		let best = 0, bestN = -1;
		for (let d = 0; d < 4; d++) {
			let n = 0;
			for (let k = 1; k <= 8; k++) { const x = hx + STEP[d][0] * k, y = hy + STEP[d][1] * k; if (inBoard(x, y) && !own(y * W + x)) n++; }
			if (n > bestN && d !== (dir + 2) % 4) { best = d; bestN = n; }
		}
		botTurn.plan = { d1: best, d2: (best + (rnd() < 0.5 ? 1 : 3)) % 4, a: 3 + Math.floor(rnd() * 5), b: 3 + Math.floor(rnd() * 6), left: false };
	}
	const plan = botTurn.plan;
	if (!plan) return dir;
	if (trailLen > 0) plan.left = true;
	const open1 = (d) => { const x = hx + STEP[d][0], y = hy + STEP[d][1]; return inBoard(x, y) && !mine(y * W + x); };
	const want = trailLen < plan.a ? plan.d1 : trailLen < plan.a + plan.b ? plan.d2 : -1;
	if (want >= 0 && open1(want)) return want;
	// 陣地への最短の道(自分の線は通れない)
	const prev = new Map([[head, -1]]);
	const q = [head];
	while (q.length) {
		const c = q.shift();
		if (c !== head && own(c)) {
			let n = c;
			while (prev.get(n) !== head) n = prev.get(n);
			const [nx, ny] = xy(n);
			return STEP.findIndex(([dx, dy]) => dx === nx - hx && dy === ny - hy);
		}
		const [cx, cy] = xy(c);
		for (const [dx, dy] of STEP) {
			const x = cx + dx, y = cy + dy, n = y * W + x;
			if (inBoard(x, y) && !prev.has(n) && !mine(n)) { prev.set(n, c); q.push(n); }
		}
	}
	return dir;
}

async function botMatch(label, shotsWanted) {
	let seed = 12345;
	const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
	let roundSeen = 0, wasWaiting = false;
	const taken = new Set();
	for (const end = Date.now() + 600000; Date.now() < end;) {
		const s = await page.state();
		if (s.screen === 'result') return s;
		const pl = s.play;
		if (!pl) { await sleep(30); continue; }
		if (pl.wait >= 0 && !wasWaiting) {
			wasWaiting = true;
			roundSeen++;
			console.log(`    ${label} ラウンド ${roundSeen}: ${pl.banner}`);
			if (roundSeen <= 2) await burst(`${label}_end${roundSeen}`);
		}
		if (pl.wait < 0) wasWaiting = false;
		for (const [name, when] of Object.entries(shotsWanted)) {
			if (!taken.has(name) && when(pl)) { taken.add(name); await shot(`${label}_${name}`); }
		}
		if (pl.phase === 1 && pl.queues[0].length === 0) {
			const d = botTurn(pl, rnd);
			if (d !== pl.dirs[0] && d !== (pl.dirs[0] + 2) % 4 && pl.queues[0].length === 0) await page.key(KEYS[0][d]);
		}
		await sleep(10);
	}
	return null;
}

const CIRCLE = Array.from({ length: 10 }, () => [[1, 1], [2, 1], [3, 1], [0, 1]]).flat();
const ROUNDS = {
	// P1 が P2 の線を踏む(P2 の線は y 4、P1 は x 28 を上る。29 回目の移動で切る)
	cut: [[[1, 20], [0, 99]], [[0, 8], [3, 99]]],
	// P1 が自分の線に入る(13 回目の移動)
	self: [[[1, 5], [0, 3], [3, 2], [2, 9]], [[3, 99]]],
	// 2 人が (24, 13) へ同時に入る(16 回目の移動)
	headon: [[[1, 99]], [[2, 1], [3, 99]]],
	// P2 が P1 の陣地を横切って右へ抜ける所を、P1 が陣地の中で回って待ってから囲む(69 回目の移動で閉じる)
	enclose: [[[2, 1], ...CIRCLE, [1, 1], [0, 6], [1, 6], [2, 8], [3, 6], [0, 99]], [[0, 10], [3, 37], [2, 11], [1, 99]]],
};

// --cpu: CPU と(やさしい)を JS の bot で 1 試合(練習から)。主の遊び方の中盤・山場・決着・結果・記録つきのタイトルを撮る
if (CPU) {
	try {
		expect(page.booted, `起動した(Godot の印字まで ${page.bootMs} ms)`);
		expect(!!(await page.waitState((s) => s.screen === 'gate', 30000)), 'S0');
		const loadedAt = Date.now();
		await page.evaluate(`localStorage.setItem('parry-duel/save', '{"version":1,"keep":"me"}')`);
		await page.key('x');
		await page.waitState((s) => s.screen === 'title');
		await page.key('Enter');
		expect(!!(await page.waitState((s) => s.screen === 'play', 3000)), 'Enter で CPU と(やさしい)');
		let last = [0, 0];
		const res = await botMatch('cpu', {
			start: (pl) => !pl.practice && pl.phase === 1 && pl.round_ticks - pl.remaining > 240,
			mid: (pl) => !pl.practice && pl.wait < 0 && pl.remaining < 2000 && pl.counts[0] > 60 && pl.trail.some((v) => v === 1),
			late: (pl) => !pl.practice && pl.wait < 0 && pl.remaining < 700 && pl.remaining > 500,
			capture: (pl) => { const hit = pl.counts[0] - last[0] >= 25 && pl.wait < 0; last = pl.counts.slice(); return hit; },
		});
		expect(!!res, `CPU との試合が S3 まで: ${res?.headline}`);
		await sleep(500);
		await page.shot('cpu_result');
		const saved = await page.saved();
		expect(Object.values(saved?.vs_cpu?.easy ?? {}).reduce((a, b) => a + b, 0) === 1, `保存に 1 試合: ${JSON.stringify(saved?.vs_cpu)}`);
		await page.key('ArrowDown');
		await page.key('Enter');
		await page.waitState((s) => s.screen === 'title', 3000);
		await sleep(400);
		await page.shot('cpu_title_record');
		const rest = 182000 - (Date.now() - loadedAt);
		if (rest > 0) await sleep(rest); // AC-22 は読み込みの後 3 分の通信を見る
		const after = page.requests.filter((r) => r.at > loadedAt);
		const secs = Math.round((Date.now() - loadedAt) / 1000);
		expect(after.length === 0 && secs >= 180, `読み込みの後の通信 ${after.length} 件(${secs} 秒見た。AC-22 は 3 分)`);
		expect((await page.evaluate(`localStorage.getItem('parry-duel/save')`)) === '{"version":1,"keep":"me"}', 'ParryDuel の保存を消さない(AC-22)');
		const errs = page.errors();
		expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).slice(0, 5).join(' / ') : ''));
		console.log('    1 フレーム(ms): ' + JSON.stringify(await page.stats()));
	} finally {
		await page.close();
		site.stop();
	}
	console.log(failureCount() === 0 ? '全部 OK' : `${failureCount()} 件 NG`);
	process.exit(failureCount() === 0 ? 0 : 1);
}

try {
	expect(page.booted, `起動した(Godot の印字まで ${page.bootMs} ms)`);
	const s0 = await page.waitState((s) => s.screen === 'gate', 30000);
	expect(!!s0, `S0 が出る(ページを開いてから ${Date.now() - page.t0} ms。NFR-5)`);
	const loadedAt = Date.now();
	expect(s0?.version === 'v0.3.0' || !!process.env.KT_ANY_VERSION, `版: ${s0?.version}`);
	await page.evaluate(`localStorage.setItem('parry-duel/save', '{"version":1,"keep":"me"}')`);
	await sleep(300);
	await shot('s0');
	await page.touch(...(await page.gameCss(640, 360)));
	await sleep(500);
	expect((await page.state()).screen === 'gate', 'タッチでは始まらない(FR-30)');
	await shot('s0_touch');
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'title')), 'キーで S1');
	await sleep(400);
	await shot('s1_title_first');
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 900, deviceScaleFactor: 1, mobile: false });
	await sleep(400);
	await shot('s1_title_tall');
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
	await sleep(300);

	// S4 設定(↓↓↓ Enter)→ キーの確かめで W と ↑ を同時に押す → Esc → Esc
	for (const k of ['ArrowDown', 'ArrowDown', 'ArrowDown', 'Enter']) await page.key(k);
	expect(!!(await page.waitState((s) => s.screen === 'settings')), '↓↓↓ Enter で設定');
	await sleep(200);
	await shot('s4_settings');
	for (const k of ['ArrowDown', 'ArrowDown', 'ArrowDown', 'Enter']) await page.key(k);
	await sleep(200);
	await page.down('w');
	await page.down('ArrowUp');
	await page.down('d');
	await sleep(200);
	await shot('s4_keytest');
	for (const k of ['w', 'ArrowUp', 'd']) await page.up(k);
	await page.key('Escape');
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.screen === 'title')), 'Esc 2 回でタイトルへ');
	const scrolled = await page.evaluate('window.scrollY');
	expect(scrolled === 0, `矢印でページが動かない(scrollY ${scrolled})`);

	// ふたりで(↓↓ Enter)。その起動で最初の試合なので練習のラウンドから
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	const pr = await page.waitState((s) => s.screen === 'play' && s.play?.practice, 5000);
	expect(!!pr, 'ふたりで → 練習のラウンド');
	await sleep(250);
	await shot('s2_count');
	let capShots = 0;
	// 練習: P1 は大きく囲み(100 マスほど)、P2 は小さく囲む。後は時間切れ
	const practiceSegs = [[[1, 12], [0, 8], [3, 11], [2, 6]], [[3, 4], [2, 4], [1, 4], [0, 2]]];
	const pre = await drive(practiceSegs, 's2_practice_end', async (p, n) => {
		if (capShots >= 2) return;
		capShots++;
		await burst(`s2_capture_p${p + 1}_${n}`, [0, 80, 160, 260, 450]);
	}, 's2_go').catch((e) => { console.log(e); return null; });
	expect(pre?.banner?.includes('広さ'), `練習は時間切れで終わる: ${pre?.banner}`);
	expect(capShots === 2, `練習で 2 人とも囲んだ(撮った ${capShots})`);

	const results = {};
	for (const name of ['cut', 'self', 'headon', 'enclose', 'cut']) {
		const r = await drive(ROUNDS[name], `s2_${name}${results[name] ? '2' : ''}`);
		results[name] = r;
		console.log(`    ${name}: ${r?.banner} 勝ち数 ${JSON.stringify(r?.wins)}`);
	}
	expect(results.cut?.banner === 'P1 の勝ち — 線を切った', `線を切った: ${results.cut?.banner}`);
	expect(results.self?.banner === 'P2 の勝ち — 自分の線に入った', `自分の線: ${results.self?.banner}`);
	expect(results.headon?.banner === '引き分け — 正面衝突', `正面衝突: ${results.headon?.banner}`);
	expect(results.enclose?.banner === 'P1 の勝ち — 囲んだ', `囲んだ: ${results.enclose?.banner}`);
	const res = await page.waitState((s) => s.screen === 'result', 8000);
	expect(res?.headline === 'P1 の勝ち  3 − 1', `S3: ${res?.headline}`);
	await sleep(400);
	await shot('s3_result_duo');
	await page.key('r');
	expect(!!(await page.waitState((s) => s.screen === 'play' && s.play && !s.play.practice, 3000)), 'R でもう1回(練習は入らない)');
	await page.waitState((s) => s.play?.phase === 1, 5000);
	await sleep(1200);
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.paused, 3000)), 'Esc で一時停止');
	await sleep(300);
	await shot('s5_pause');
	const r0 = (await play()).remaining;
	await sleep(800);
	expect((await play()).remaining === r0, '一時停止の間、残り時間が減らない');
	await page.key('Escape');
	expect(!!(await page.waitState((s) => !s.paused, 3000)), 'Esc で続ける');
	await page.hide();
	await sleep(800);
	await page.show();
	expect(!!(await page.waitState((s) => s.paused, 5000)), 'タブが裏に回ると一時停止(E-13)');
	for (const k of ['ArrowDown', 'ArrowDown', 'ArrowDown', 'Enter']) await page.key(k);
	expect(!!(await page.waitState((s) => s.screen === 'title', 3000)), '一時停止からタイトルへ');

	// 揺れ 切・点滅を弱める 入 で、線を切った決着が動かず、光が弱い
	for (const k of ['ArrowDown', 'ArrowDown', 'ArrowDown', 'Enter']) await page.key(k);
	await page.waitState((s) => s.screen === 'settings', 3000);
	for (const k of ['ArrowDown', 'Enter', 'ArrowDown', 'Enter']) await page.key(k);
	await sleep(200);
	await shot('s4_settings_changed');
	const st = (await page.saved())?.settings;
	expect(st?.shake === false && st?.reduce_flash === true, `設定が保存に入る: ${JSON.stringify(st)}`);
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title', 3000);
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'play', 3000);
	let moved = false;
	const watch = (async () => {
		for (const end = Date.now() + 40000; Date.now() < end;) {
			const pl = await play();
			if (pl?.pos?.some((v) => v !== 0)) moved = true;
			if (pl?.wait > 60) break;
			await sleep(15);
		}
	})();
	const rr = await drive(ROUNDS.cut, 's2_cut_reduced');
	await watch;
	expect(rr?.banner === 'P1 の勝ち — 線を切った' && !moved, `揺れを切ると決着で画面が動かない(${rr?.banner}、動いた: ${moved})`);

	const after = page.requests.filter((r) => r.at > loadedAt);
	expect(after.length === 0, `読み込みの後の通信 ${after.length} 件(${Math.round((Date.now() - loadedAt) / 1000)} 秒見た)` + (after.length ? ': ' + after.map((r) => r.url).join(', ') : ''));
	const saved = await page.saved();
	expect(saved?.version === 1, `保存は key-turf/save: ${JSON.stringify(saved)}`);
	expect((await page.evaluate(`localStorage.getItem('parry-duel/save')`)) === '{"version":1,"keep":"me"}', 'ParryDuel の保存を消さない(AC-22)');
	console.log('    1 フレーム(ms): ' + JSON.stringify(await page.stats()));
	console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));

	// キーの確かめの画面(?keys=1)
	const base = page.url0.split('?')[0];
	expect(await page.goto(base + '?keys=1&debug=1'), 'キーの確かめの画面を開き直す');
	await page.waitState((s) => s.screen === 'gate', 20000);
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'keys', 3000)), '?keys=1 でキーの確かめの画面');
	const names = [];
	for (const k of ['w', 'a', 's', 'd', 'ArrowUp', 'ArrowLeft', 'ArrowDown', 'ArrowRight']) {
		await page.key(k);
		await sleep(30);
		names.push((await page.state()).keys.at(-1).pk_name);
	}
	expect(names.join(' ') === 'W A S D Up Left Down Right', `8 キーの physical_keycode: ${names.join(' ')}`);
	await shot('keys');
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).slice(0, 5).join(' / ') : ''));
} finally {
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? '全部 OK' : `${failureCount()} 件 NG`);
process.exit(failureCount() === 0 ? 0 : 1);
