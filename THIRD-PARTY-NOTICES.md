# 第三者の素材

同梱している第三者の素材は、次の字体 2 つだけです。効果音は `tools/gen_sfx.py` で合成した自作の物です。

## Noto Sans JP(画面の字)

- ファイル: `assets/fonts/NotoSansJP-Subset.ttf`(原本を、画面に出す文字だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/notosansjp の `NotoSansJP[wght].ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_NotoSansJP.txt`](assets/fonts/OFL_NotoSansJP.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'

## Lilita One(題字と数字。v0.3.0 から)

- ファイル: `assets/fonts/LilitaOne-Regular.ttf`(原本のまま。手を加えていない。Reserved Font Name があるので、絞り込みなどの改変版は作らない)
- 原本: https://github.com/google/fonts/tree/main/ofl/lilitaone の `LilitaOne-Regular.ttf`(コミット `90abd17b4f97671435798b6147b698aa9087612f`。git の blob `fdec368cbd478e437f0476a538c3868723aed296` が一致)
- 原本の SHA-256: `f5b641c45c69d772ee4eda687bc9fda411d5cad6b0b45371491da4580cbc8d59`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_LilitaOne.txt`](assets/fonts/OFL_LilitaOne.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright (c) 2011 Juan Montoreano, with Reserved Font Name Lilita

## 効果音

- ファイル: `assets/sfx/*.wav`(12 個。v0.3.0 で UI の `select.wav`・`confirm.wav` を足した)
- 出どころ: `tools/gen_sfx.py` で合成した自作の音。第三者の素材は使っていない。ライセンスはリポジトリと同じ MIT。
