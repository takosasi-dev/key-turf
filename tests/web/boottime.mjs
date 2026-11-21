// 起動までの秒数を測る(ページを開いてから S0 の状態が出るまで)。毎回、使い捨てのプロフィールで Chrome を立ち上げ直す。作りは KeySwat の boot.mjs。
//     node tests/web/boottime.mjs 3                                  手元の build/web を 3 回
//     KT_WEB=build/web_v020 node tests/web/boottime.mjs 3            前の版の書き出しを 3 回(交互に測って比べる)
//     KT_URL=https://…/key-turf/ node tests/web/boottime.mjs 3       公開した物を 3 回
import { open, serve } from './lib.mjs';

const N = Number(process.argv[2] || 3);
const site = serve();
const times = [];
try {
	for (let i = 0; i < N; i++) {
		const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
		try {
			const s = await page.waitState((st) => st.screen === 'gate', 60000);
			times.push(s ? Date.now() - page.t0 : NaN);
			console.log(`${i + 1} 回目: S0 まで ${times.at(-1)} ms・エラー ${page.errors().length} 件・版 ${s?.version}`);
		} finally {
			await page.close();
		}
	}
} finally {
	site.stop();
}
console.log(`S0 まで(ms): ${times.join(' / ')}`);
