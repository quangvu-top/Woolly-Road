# Làm một game như Crash Ramp

Hướng dẫn từng bước cho AI agent (và người) làm một game hybrid-casual 3D bằng Horus SDK, ra kết quả cùng loại với **Crash Ramp: Car Upgrade** của Horus: một màn chơi ngắn, tiền kiếm được theo quãng đường, nâng cấp giữa các lượt, nhiều map nối nhau, quảng cáo rewarded và interstitial, shop gem, offer, lưu và cloud save, analytics, Remote Config, thông báo nhắc chơi, rồi build ra Android/iOS qua Horus.

Cách dùng: làm lần lượt từ bước 0. Mỗi bước có **Xong khi**: kiểm đủ các ý đó rồi mới sang bước sau. Con số trong hướng dẫn là của Crash Ramp (bản 0.1.0 trên store), dùng làm điểm xuất phát rồi chỉnh theo game. API đầy đủ: `horus-sdk.d.ts`; quy tắc ngắn: `AGENTS.md`. Game Godot: `godot/README.md` và `godot/AGENTS.md`.

## Prompt cho agent

Dán vào Claude Code, Cursor, Codex... ở gốc repo game (đã chép gói SDK vào `horus-sdk/`). Sửa phần trong `< >`.

**Bắt đầu game mới:**

```
Đọc hết horus-sdk/GAME-GUIDE.md và horus-sdk/AGENTS.md trước khi viết code.
Làm game "<tên game>": <2-3 câu: người chơi làm gì trong một lượt, tiền theo gì, nâng cấp gì, map sau khác gì>.
Game tham khảo: <tên hoặc link>. Hướng màn hình: <portrait/landscape>. Số map đầu tiên: <6>.

Làm đúng thứ tự các bước 0 đến 19 của GAME-GUIDE.md:
- Bước 0: viết docs/design.md, hỏi tôi những gì chưa rõ và chờ tôi đồng ý rồi mới làm tiếp.
- Sau mỗi bước: kiểm đủ mục "Xong khi" của bước đó trên trình duyệt ở cỡ điện thoại, báo tôi một dòng
  (bước nào xong, đã kiểm gì), rồi làm bước kế. Một mục chưa đạt thì sửa, không bỏ qua.
- Mọi con số để trong src/config.js, bắt đầu từ số của Crash Ramp trong hướng dẫn. Đổi kinh tế thì chạy
  mô phỏng (economy.simulateEconomy) và cho tôi xem bảng trước khi chốt.
- Chỉ dùng Horus SDK cho quảng cáo, mua hàng, analytics, lưu game; không thêm SDK hay thư viện tracking nào khác,
  không tải gì từ CDN, không sửa file trong horus-sdk/.
- Build: chỉ --dry-run và APK thử. --play hay --ios chỉ khi tôi bảo.
```

**Phiên mới, làm tiếp:**

```
Đọc docs/design.md, horus-sdk/GAME-GUIDE.md và horus-sdk/AGENTS.md. Xem lại từng bước 0 đến 19 theo mục "Xong khi"
(chạy game trên trình duyệt để kiểm, đừng đoán), cho tôi bảng bước nào xong, bước nào chưa, rồi làm tiếp bước đầu tiên chưa xong.
```

**Kiểm trước khi gửi build:**

```
Kiểm game theo bước 18 của horus-sdk/GAME-GUIDE.md và mục "Kiểm tra trước khi báo xong" của horus-sdk/AGENTS.md.
Sửa mọi lỗi tìm thấy, chạy node horus-sdk/horus-build.mjs --dry-run tới khi không còn dòng "chú ý:", rồi build APK thử
và báo tôi đường dẫn file.
```

**Game chậm trên máy yếu:**

```
Game chạy <N> khung/giây trên <tên máy>. Đọc mục 5 của horus-sdk/GAME-GUIDE.md. Đo trước (bench trên máy thật,
đếm lệnh vẽ, profile CPU), cho tôi bảng thời gian GPU và JS mỗi khung và việc định làm. Chỉ làm những việc giữ
nguyên hình (so từng điểm ảnh, lệch tối đa 1/255); việc nào đổi hình (hạ độ nét, tắt bóng, tắt bloom) thì hỏi tôi trước.
```

**Có crash mới:**

```
Crashlytics có crash/ANR mới: <mã issue hoặc ảnh chụp>. Làm theo mục 21 của horus-sdk/GAME-GUIDE.md: bao nhiêu người
chơi thật, bản nào, máy và WebView nào; nguyên nhân kèm bằng chứng (stack, sự kiện analytics trước lỗi); sửa kèm test.
Nói rõ khi nào mới biết chắc đã hết lỗi.
```

**Đổi một con số hay một luật:**

```
<Ví dụ: Map 1 dễ quá, người chơi qua trong 5 phút>. Sửa trong src/config.js (không sửa code chơi), chạy lại mô phỏng
cho 3 kiểu người chơi, cho tôi xem bảng trước và sau, ghi quyết định vào docs/design.md kèm ngày.
```

## 0. Trước khi viết code

Viết ra (trong `docs/design.md` của repo game) năm dòng: vòng chơi một lượt (người chơi làm gì trong 10 đến 40 giây), cái gì quyết định lượt đó đi xa hay gần, tiền nhận theo gì, nâng cấp gì, và map sau khác map trước thế nào.

Crash Ramp: kéo ná bắn xe xuống dốc; xe bay, lướt, đâm qua cổng; tiền theo mét đi được; ba nâng cấp (Ná: lực bắn, Xe: lướt và bám đường, Thu nhập: tiền mỗi mét); về đích một map thì mở map sau, xe mới, giá và tiền mỗi mét cao hơn.

Hỏi người dùng nếu chưa rõ: hướng màn hình, số map đầu tiên, game tham khảo, có online hay không (SDK này cho game offline; chơi mạng cần nói chuyện với Horus).

**Xong khi:** có `docs/design.md` với năm dòng trên, người dùng đồng ý.

## 1. Thư mục game

```
my-game/
  horus-sdk/            gói SDK, chép nguyên, không sửa
  horus-game.json       thông tin game gửi Horus (bước 2)
  icon.png              1024×1024, không bo góc
  package.json          "build": lệnh ra bản web
  build.mjs             esbuild: src/ -> www/ (hoặc dist/)
  src/
    main.js             khởi động (bước 4)
    config.js           MỌI con số của game: giá, tiền, luật quảng cáo, offer, thông báo
    save.js             kho lưu (bước 11)
    game.js             vòng chơi, trạng thái màn hình
    world.js            cảnh three.js, map
    ui.js               HUD, menu, thẻ nâng cấp, shop, popup (HTML/CSS trên canvas)
    analytics.js        tên sự kiện, phễu FTUE (bước 13)
    notify.js           lịch thông báo (bước 15)
    i18n/en.json ...    chữ theo ngôn ngữ (bước 17)
  www/                  bản build web (gửi đi), không commit
  build-online/         APK/AAB tải về, không commit
```

`package.json` của Crash Ramp:

```json
{
  "type": "module",
  "scripts": { "build": "node build.mjs --target=android", "web": "node build.mjs", "ui": "node horus-sdk/horus-build.mjs ui" },
  "dependencies": { "esbuild": "0.28.2", "three": "0.186.1" }
}
```

Dùng ES module và import SDK một chỗ duy nhất:

```js
// src/sdk.js: mọi file khác import từ đây
export { platform, start, save, cloud, monetize, liveops, economy, app, fx, perf } from '../horus-sdk/horus-sdk.mjs';
```

Bản build gộp mọi thứ vào `www/` (index.html, game.js, model, âm thanh, font), đường dẫn tương đối, không tải gì từ CDN.

**Xong khi:** `npm install && npm run build` ra `www/index.html` mở được qua `npx serve www`, Console không lỗi; `.gitignore` có `www/`, `build-online/`, `node_modules/`.

## 2. horus-game.json

Điền đủ ngay từ đầu, và sửa mỗi khi thêm placement, SKU, khoá Remote Config hay sự kiện. Horus cài quảng cáo, store và Firebase từ file này.

```json
{
  "name": "My Game",
  "version": "0.1.0",
  "versionCode": 1,
  "appId": "",
  "web": "www",
  "build": "npm install --no-audit --no-fund && npm run build",
  "icon": "icon.png",
  "orientation": "portrait",
  "colors": { "background": "#0B1030" },
  "languages": ["en", "vi"],
  "ads": {
    "rewarded": ["x2_coins", "upgrade_free", "shop_gems", "rocket_free", "comeback_x2"],
    "inter": ["result_exit"]
  },
  "products": [
    { "sku": "gems_pack_1", "usd": 2.99, "consumable": true, "title": "10 gems" },
    { "sku": "gems_pack_2", "usd": 6.99, "consumable": true, "title": "30 gems" },
    { "sku": "gems_pack_3", "usd": 14.99, "consumable": true, "title": "100 gems" },
    { "sku": "remove_ads", "usd": 4.99, "consumable": false, "title": "Remove ads" },
    { "sku": "starter_pack", "usd": 6.99, "consumable": false, "title": "Starter pack" },
    { "sku": "upgrade_pack", "usd": 0.99, "consumable": true, "title": "Upgrade pack" }
  ],
  "remoteConfig": { "ads_interEvery": "2", "ads_interCooldown": "120", "m1_priceGrowth": "1.45", "offer_on": "1" },
  "events": ["run_start", "run_end", "upgrade", "map_clear", "rv_offer", "rv_start", "rv_done", "inter_show", "offer_show", "offer_buy"],
  "support": "support@horusvn.com",
  "notes": "Hybrid-casual 3D, 6 maps. Gems only from ads and IAP."
}
```

Quy tắc: placement chữ thường không dấu; SKU không bao giờ đổi sau khi đã lên store (đặt tên theo gói, không theo số gem: `gems_pack_1`, không `gems_80`); `appId` để trống tới khi Horus cấp.

**Xong khi:** mọi placement, SKU, khoá Remote Config và sự kiện mà code dùng đều có trong file (tìm trong `src/` bằng grep và so).

## 3. Một file config cho mọi con số

Mọi số ảnh hưởng tới kinh tế và quảng cáo nằm trong `src/config.js`, dạng object để Remote Config ghi đè được (bước 14). Không viết số thẳng trong `game.js` hay `ui.js`.

```js
// src/config.js (Crash Ramp)
export const M1 = { priceBase: 60, priceGrowth: 1.45, pay: 0.14, startCoins: 60, clear: 8000 };   // Map 1
export const UPGRADES = [
  { id: 'sling',  name: 'Slingshot' },   // lực bắn
  { id: 'car',    name: 'Car' },         // lướt, bám đường, chịu va chạm
  { id: 'income', name: 'Income' },      // tiền mỗi mét
];
export const MAX_LEVEL = 100;
export const LEVEL_LEN = [1500, 1900, 2100, 2300, 2600, 2900];   // mét mỗi map
export const GEMS = { start: 10, adReward: 1 };                   // gem chỉ từ quảng cáo (1 video = 1 gem) và IAP
export const ADS = { ...monetize.INTER_DEFAULTS, interOnX2Skip: 1, interFromRun: 4, interEvery: 2, interCooldown: 120, sessionWarmup: 90, rewardedGrace: 45, rvWaitMs: 3000 };
export const SHORT = { ...monetize.SHORT_DEFAULTS, afterBuys: 1, freeAds: 1, gemStep: 1, adsForGems: 1, maxSteps: 0, pin: 1, fromRun: 2 };
```

**Xong khi:** `grep -n "[0-9]\{3,\}" src/game.js src/ui.js` không còn giá, tiền thưởng hay thời gian chờ quảng cáo nào.

## 4. Thứ tự khởi động

Đúng thứ tự này, trong `src/main.js`. Sai thứ tự là mất tiến độ hoặc giao hàng hai lần.

```js
import { platform, start, save, cloud } from './sdk.js';
import { store, further, merge } from './save.js';
import { ALL_SKUS, applyRemoteConfig } from './config.js';

window.addEventListener('error', (e) => platform.crash(e.message, e.error?.stack));
window.addEventListener('unhandledrejection', (e) => platform.crash(String(e.reason?.message || e.reason), e.reason?.stack));

async function boot() {
  await start({ skus: ALL_SKUS() });                  // 1. app info, Remote Config, giá store, cloud save
  store.restoreBackup(platform.save.backup);          // 2. máy trống: lấy bản dự phòng của app
  await cloud.settleAtBoot(platform, save.conflictRules(store, {   // 3. server khác máy: giữ bản đi xa hơn
    further, merge, mirror: (j) => platform.save.mirror(j), flush: () => platform.save.flush(),
  }));
  applyRemoteConfig(platform.rc.values);              // 4. Remote Config ghi đè config.js
  await setLang(pickLang());                          // 5. ngôn ngữ trước khi vẽ chữ
  const game = new Game(store.load());                // 6. đọc save
  for (const p of await platform.iap.pending()) game.grant(p);   // 7. đơn đã trả tiền chưa giao
  recoverLostAds(game);                                // 7b. quảng cáo thưởng xem hết lúc trang bị tắt (bước 8)
  await game.loadFirstMap();
  game.start();
  platform.ready();                                    // 8. app tắt màn hình chờ
}
boot().catch((e) => { console.error(e); platform.ready(); });
```

Màn hình chờ của `index.html` (một div tên game trên nền `colors.background`) hiện tới khi map đầu đã dựng.

**Xong khi:** mở trang, thấy màn chờ rồi menu trong dưới 3 giây trên máy tính; tải lại trang, tiến độ còn; Console không lỗi.

## 5. Vỏ three.js và ngân sách hiệu năng

Dùng `app.createApp` thay vì tự dựng renderer: nó chỉnh cho điện thoại (pixel ratio, mất context WebGL, governor hạ chất lượng khi tụt khung). Truyền `THREE` của game vào; SDK không chứa three.js.

```js
import * as THREE from 'three';
import { app as A, fx as F, perf } from './sdk.js';

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(55, 1, 0.1, 800);
const effects = new F.Fx(THREE, scene);
const shell = A.createApp({
  THREE, canvas: document.querySelector('canvas'), tickHz: 60,
  onTick: () => game.step(1 / 60),                 // vật lý bước cố định
  onFrame: (now) => { effects.update(now / 1000); shell.render(scene, camera); },
  onResize: (w, h) => { camera.aspect = w / h; camera.updateProjectionMatrix(); },
  onTier: (tier) => game.setQuality(tier),         // tier cao = máy yếu: bớt bóng, bớt hạt
});
shell.start();
```

Ngân sách cho máy tầm trung (mục tiêu 60 khung/giây): dưới 150 draw call (máy yếu như Galaxy A10: dưới 80), dưới 300 nghìn tam giác trên màn hình, một đèn có bóng, bóng nướng sẵn cho cảnh tĩnh, texture tối đa 1024, model gộp mesh theo vật liệu. Hiệu ứng hạt dùng `fx.Fx` (tối đa 4 draw call cho mọi hạt), xu bay về ví dùng `fx.createCoinFly` trên lớp HTML.

Màn 90/120 Hz: gọi `platform.device.setFrameRate(60)` lúc mở game và vẽ tối đa 60 khung/giây (bỏ khung `requestAnimationFrame` thừa), cho đổi bằng Remote Config. Nhanh hơn 60 chỉ làm máy nóng và tốn pin, người chơi không thấy khác (Crash Ramp v87).

Nhạc nền dùng `.mp3`, không `.ogg`: iPhone đời cũ không giải mã được `.ogg` và game mất nhạc mà không báo lỗi. Khi `pause` thì nhả nhạc nền khỏi bộ nhớ, `resume` thì nạp lại: máy RAM thấp hay giết WebView khi game ở nền (Crash Ramp v90).

### Máy yếu và WebView cũ

Nhiều máy Android 10 rẻ chưa bao giờ cập nhật WebView: Galaxy A10 (2 GB) trong Firebase Test Lab chạy Chrome 81. Build JS cho Chrome 80 (`?.` và `??` có từ 80; dưới đó trang không chạy). Từ SDK 0.26.1 file Horus SDK tự thêm những hàm mới hơn mà game hay gọi, chỉ khi WebView thiếu (`@horus/webgame/compat`, game dùng kit thì `import '@horus/webgame/compat';` ở dòng đầu tiên của `main.js`): `Array.prototype.at` (Chrome 92), `Element.prototype.replaceChildren` (86), `CanvasRenderingContext2D.prototype.roundRect` (99), `Element.animate()` với keyframe thiếu thuộc tính và `Element.getAnimations()` (84). Ở Crash Ramp, một `.at()` trong bench làm cả bài test trên A10 không ra kết quả (v97d); `animate([{ opacity: 0 }])` (chỉ một keyframe) ném lỗi lúc dựng Map 2 nên trang tải lại, và `getAnimations()` thiếu làm game kẹt ở thẻ kết quả (v98c).

Những thứ polyfill không cứu được, tự tránh: `String.prototype.replaceAll` (Chrome 85: dùng `.split(a).join(b)` hoặc regex `/g`; một bản thử Crash Ramp trên A10 không vẽ gì vì nó), CSS `:where()` (Chrome 88: WebView cũ bỏ cả rule, nên viết thêm một selector thường cho rule quan trọng), thuộc tính CSS `inset` (87: để bước build hạ xuống `top/right/bottom/left`).

Máy có WebView dưới 80 thì game không chạy và cũng không gửi được gì. Từ @horus/webgame 0.49.0 app Android tự kiểm trước khi mở game: WebView cũ hơn `android.minWebView` (mặc định 80) thì hiện màn có nút mở trang WebView trong Play Store để cập nhật, và ghi `webview_old` `{ wv, min, pkg }` để đếm số máy như vậy. Game build cho Chrome thấp hơn 80 thì hạ `android.minWebView` theo.

Đổi map trên máy 2 GB là lúc dễ chết nhất: RAM gần hết, GPU có thể ngừng trả khung hình. Crash Ramp v97f trên A10 đứng ở màn chờ Map 2 mãi vì code nạp map chờ `requestAnimationFrame` không giới hạn. Luật từ v97g:
- Giải phóng map cũ (mesh, texture, xe) trước khi dựng map mới.
- Mọi lần chờ khung hình trong lúc nạp tối đa 100 ms; dịch shader trước (`precompile` / `compileAsync`) tối đa 8 giây.
- Bọc hàm nạp map bằng try/catch và một watchdog: 30 giây không có bước nào tiến thì ghi map mới vào save rồi tải lại trang, để map mới dựng từ trang sạch. Tối đa một lần tải lại mỗi phút; lần sau thì hiện nút "tải lại", không lặp.
- Thời gian app nằm nền không tính vào 30 giây đó: khi trang ẩn, hoặc timer của watchdog bị giữ lâu hơn 15 giây, thì đếm lại từ lúc trang hiện lại. Nếu không, người chơi chuyển sang app khác trong lần mở đầu (máy yếu tải 15-70 giây) sẽ bị tải lại từ đầu khi quay về (Crash Ramp v98a).
- Mất context WebGL trong lúc nạp thì cũng tải lại (cùng giới hạn một lần mỗi phút).
- Không đặt timer cần WebGL trước khi WebGL có: app bị chuyển ra nền ngay lúc mở thì context chưa có. Gửi `boot_fail` và tải lại khi trang hiện lại.

### Tối ưu GPU máy yếu, không đổi hình

Crash Ramp trên Galaxy A10 (Mali-G71 MP2, 2 GB, WebView 81) chạy 12 khung/giây ở Map 1: GPU khoảng 83 ms mỗi khung, JS khoảng 30 ms. Mục tiêu trên 30 khung/giây mà hình không đổi. Luật rút ra (v98g đến v98q):

**Đo trên máy yếu thật trước khi sửa.** Firebase Test Lab có A10 trong quota miễn phí (30 phút máy thật mỗi ngày, ngày tính theo nửa đêm giờ Pacific; không trả phí). Game có bench tự chơi (`?bench`, chạy bằng Game Loop của Test Lab) báo fps, ms JS chia phần update của game và phần render của three, và các biến thể bỏ từng phần (mặt đất, cảnh vật, trời, hậu kỳ, cảnh rỗng) để biết khung đi đâu. Mỗi lần chạy chỉ một máy, không chạy lại khi lỗi.

**Ngân sách.** Mali-G71 MP2 khoảng 2 lõi × 450 MHz: 30 khung/giây là khoảng 30 triệu chu kỳ shader mỗi khung. Màn 412×869 ở 1.5x là khoảng 800 nghìn điểm ảnh, tức khoảng 37 chu kỳ mỗi điểm ảnh cho mọi thứ, kể cả hậu kỳ. Đo chu kỳ của shader thật bằng Mali Offline Compiler (Arm Performance Studio, chạy trong Docker không mạng): dump nguồn GLSL của từng program sau khi three compile (`gl.getShaderSource`), rồi so đường dài nhất. Shader mặt đất của Crash Ramp: 76 chu kỳ, dùng 64 thanh ghi (một nửa số luồng).

**Tìm phần nặng trong một shader.** Từ nguồn GLSL đã dump, làm vài bản chẩn đoán, mỗi bản bỏ đúng một phần (gán hằng số cho một biến). Chạy Mali Offline Compiler cho từng bản và so đường dài nhất với bản gốc. Các bản này chỉ để đo, không đưa vào game. Crash Ramp v100c, mặt đất Map 1 (ánh sáng theo đỉnh), 2/11/2026:

| Bản | Mali-G52 (chu kỳ) | Mali-G68 (chu kỳ) |
|---|---|---|
| Nguyên bản | 18,0 | 15,1 |
| Bỏ phần màu đường | 11,5 (−36%) | 10,1 (−33%) |
| Bỏ khối đá | 15,0 (−17%) | 12,4 (−18%) |
| Bỏ các lần đọc nhiễu chi tiết | 17,0 (−6%) | 14,5 (−4%) |
| Bỏ bóng nướng | 17,7 (−2%) | 14,9 (−2%) |

Shader không tràn thanh ghi ra bộ nhớ và không có phép tính 16 bit. Phần nặng là các phép tính màu của đường và đá, không phải số lần đọc texture.

Đổi varying trong `onBeforeCompile` (ví dụ sang `mediump`): các varying của three (`vNormal`, `vColor`...) lúc đó vẫn còn là dòng `#include <normal_pars_fragment>`, chỉ hiện ra khi three ghép chunk sau `onBeforeCompile`. Phép thay chữ không khớp mà không báo lỗi. Viết chunk ra trước (`THREE.ShaderChunk[...]`) rồi mới thay, và luôn kiểm bằng shader đã dịch (`gl.getShaderSource`), không bằng chuỗi nguồn. Crash Ramp v100f thiếu vNormal nên đường đất trên G68 vẫn 50 thanh ghi; v100h sửa.

**Một khung 3x đi vào đâu** (Galaxy A16, Mali-G68 MP2, Chrome, Crash Ramp v100g/h Map 1 lúc bắt đầu, 1080x1929, 2/11/2026; cách đo ở "Đo cho đúng"). Khung có bloom như người chơi thấy: khoảng 25 ms GPU, tức tối đa khoảng 40 fps. Mỗi dòng là thời gian khung bớt đi khi bỏ phần đó:

| Phần | ms | Phần | ms |
|---|---|---|---|
| Bầu trời (shader tính mỗi điểm ảnh) | 4,4 | Hậu kỳ (target trung gian + pass toàn màn) | 2,0 |
| Bloom, trong đó pass lọc sáng đọc cả cảnh 3x 3,1 | 4,3 | Bóng thật của xe | 1,2 |
| Cây, bụi, đá (ánh sáng theo đỉnh) | 3,4 | Cỏ | 0,6 |
| Mặt đất | 3,7 | Xe | 0 |

Trên G68, đổi target và pass rỗng gần như không tốn: 5 pass vào target 4x4 thêm 0,0 ms. Phép tính của pass cuối chỉ khoảng 0,3 ms, target half float thay 8 bit chỉ khoảng 0,2 ms. JS khoảng 4 ms mỗi khung cho phần vẽ, 6-7 ms khi đang chạy: GPU là chỗ nghẽn. Đo cả khung trước khi tối ưu một shader. Bầu trời nặng hơn mặt đất, và bench cũ chưa từng tách riêng nó ra.

Tách tiếp từng phần (v100j, cùng cách đo):
- **Bầu trời:** khoảng 29 chu kỳ mỗi điểm ảnh trên G68 (phần mây), gấp 2-3 lần mặt đất, phủ nửa trên màn hình.
- **Cây, bụi, đá:** tắt ghi màu của chúng (vẫn chạy shader đỉnh, raster, độ sâu) vẫn còn 3,0 trong 3,4 ms. Chi phí nằm ở đỉnh (187 nghìn tam giác), không ở điểm ảnh. Shader điểm ảnh chỉ khoảng 3 chu kỳ, shader đỉnh nghẽn ở đọc dữ liệu.
- **Pass lọc sáng của bloom:** nghẽn ở đọc texture half float có lọc. Cùng pass trên cảnh 8 bit chỉ 0,3 ms thay vì 3,0; một mẫu thay vì bốn: 1,3 ms.
- **Varying 16 bit cho cỏ hai mặt và cho mây:** mỗi cái 0,3 ms. Ảnh lệch tối đa 2/255.
- **Cảnh vật đứng yên, không đổ bóng, chỉ vẽ instance trong tầm nhìn (v100k):** đỡ 0,7 ms. Thời gian JS của phép lọc không đo ra được trên đường chạy.
- **Nhiễu của mây đọc bằng một lần lấy mẫu có lọc của texture (v100l), thay vì `texelFetch` rồi tự trộn 4 góc:** đỡ 1,2 ms. Ảnh lệch 1/255 trên 1,2% điểm ảnh.
- **Sau v100l:** khung có bloom còn khoảng 21 ms ở 3x (trước v100f khoảng 25 ms).

- **Ẩn hết mọi vật (chỉ còn xoá target HDR và pass cuối):** vẫn tốn 3,6 ms, trong khi xoá canvas thẳng chỉ tốn 0,5 ms. Riêng việc vẽ qua target trung gian ở 3x đã khoảng 3 ms.
- **Núi xa, ná, xu, hạt, chim:** mỗi thứ khoảng 0 ms.
- **Bóng xe:** vẽ bản đồ bóng 0,6 ms, lấy mẫu bóng 0,4 ms.
- **Bầu trời:** chiếm 42% điểm ảnh ở góc nhìn đầu Map 1.
- Bớt từng phần thì không cộng dồn được: ẩn mặt đất lộ ra trời, ẩn cây lộ ra đất.
- **Độ nét, khung có bloom như người chơi thấy (v100l, khung đứng yên):**

  | Độ nét | 3x | 2,75x | 2,5x | 2,25x | 2x |
  |---|---|---|---|---|---|
  | GPU mỗi khung | 21,4 ms | 18,3 | 16,1 | 14,5 | 12,4 |

  Trên đường chạy: 3x 33,8 fps, 2,5x 44,8 fps; JS khoảng 7,7 ms ở cả hai.
- **HUD bằng DOM là phần nặng nhất khi đang chạy (v100n):** trên đường, ẩn HUD (`display:none`) đưa A16 ở 3x từ 34,3 lên 48,7 fps. Khoảng cách khung giảm từ 28,9 xuống 21,1 ms, khung từ 37 ms trở lên giảm từ 27% xuống 3%. Khi khung đứng yên, HUD chỉ tốn khoảng 1,5 ms. Cái đắt là HUD đổi mỗi khung (chữ, vòng tốc độ, transform): trình duyệt phải vẽ lại ở tỉ lệ điểm ảnh 3 rồi ghép lên canvas.
  - Đo khoảng 8 ms chênh giữa khung đứng yên và khung đang chạy: ẩn HUD trước, rồi mới nghi tới GPU.
  - Cùng lần đo, xung GPU vẫn 949 MHz, bận 94%. Đóng băng bản đồ bóng chỉ được 7%.
  - Xung và độ bận của GPU đọc được không cần root: `adb shell cat /sys/kernel/gpu/gpu_clock /sys/kernel/gpu/gpu_busy` (Samsung Exynos).
  - Cách sửa giữ nguyên hình (v100r): mỗi phần HUD đổi mỗi khung (khoảng cách, tốc độ, thanh) có lớp ghép riêng, `will-change: transform` trên từng widget, không bao giờ trên khung chứa phủ cả màn. Không có thì Chrome vẽ lại một lớp cả màn ở tỉ lệ điểm ảnh của máy mỗi khung rồi trộn lên game: A16 ở 3x tốn khoảng 10 ms một khung khi đang chạy, tách lớp lấy lại khoảng 6 ms (trên đường 31,6 lên 38,4 fps, hình như cũ).
  - Canvas phủ cả màn đang rảnh (như canvas CoinFly) thì ẩn bằng `visibility:hidden`.
  - Kiểm bằng CDP `LayerTree` trong một lượt chạy: ngoài canvas game không còn lớp nào to bằng màn hình.
  - Phần tử HUD có lớp ghép riêng (`will-change: transform`, hoặc đang animate transform) không được mang `filter` (drop-shadow, blur), kể cả filter đứng yên. Đo trên OPPO A15 (PowerVR GE8320), nút tên lửa đang có gợi ý của Crash Ramp: bỏ filter mà giữ animation scale thì nhanh hơn 10 ms mỗi khung. Bỏ animation mà giữ filter tĩnh (v100y) thì không nhanh hơn chút nào (1 ms). Ẩn hẳn nút: 12 ms. Có lẽ compositor áp lại filter của lớp đó mỗi khung. Glow thì vẽ thẳng vào nội dung lớp: `box-shadow` tĩnh hoặc nền `radial-gradient` (thêm pseudo-element nếu cần), rồi chỉ animate `transform` và `opacity`. Cũng không animate `box-shadow` hay `text-shadow`, vì chúng vẽ lại mỗi khung.
    - Đã kiểm (v100z): glow bằng `box-shadow` tĩnh, `filter: none`, chỉ animate scale. Khi gợi ý bật: 42,9 ms một khung, bản dùng filter tĩnh 56,3 ms (23,1 so với 18,5 fps cả lượt). Khung có gợi ý không còn chậm hơn khung không có.
  - Web Animation (`element.animate`) không có `fill` thì hủy khi xong: `a.onfinish = () => a.cancel()`. Còn gắn trên phần tử thì các CSS animation của phần tử đó không chạy trên compositor (Crash Ramp v101b, trace Chrome: compositeFailed 64, khoảng 120 lần tính lại style + 1.000 lần cập nhật layer mỗi 2 giây trên luồng chính).
- **Máy rất yếu, OPPO A15 (Helio P35, PowerVR GE8320, 2,9 GB RAM, màn 720x1600 60 Hz, tỉ lệ điểm ảnh 2), Crash Ramp v100t trong Chrome, đang chạy:**

  | Độ nét | 2x | 1,5x | 1,25x | 1x | 1x, ẩn HUD |
  |---|---|---|---|---|---|
  | fps | 10,3 | 15,6 | 18,6 | 19,6 | 24,2 |

  - JS khoảng 21 ms mỗi khung (update 5,4 + render 16,1 ms trên lõi A53), nên riêng CPU đã chặn khoảng 45 fps.
  - HUD bằng DOM tốn khoảng 10 ms, vì DOM vẫn vẽ ở tỉ lệ 2 dù canvas để 1x.
  - Bản Play tester đo được 18,9 fps.
  - Cùng máy, một game Unity thủ thành (Unity 2022.3, IL2CPP, GLES) đạt 57,8 fps ở đủ 720x1600: cảnh nhìn từ trên xuống, nền phẳng, phần CPU chạy hai luồng mã máy.
  - Ở 1x một khung khoảng 51 ms: mặt đất khoảng 13 ms, cây cỏ 13, trời 5, xe 5. Không vẽ cảnh 3D nào, trang vẫn tốn khoảng 20 ms (update, ghép HUD, trình chiếu). Máy nghẽn ở GPU.
  - Thử cấu hình máy yếu trên chính máy này (đang chạy, mỗi cấu hình một lượt riêng):
    - mức thấp nhất hiện nay (1x, không bloom, có bóng, target HDR): 18,2 fps;
    - bỏ bóng thời gian thực, bỏ target HDR và pass hậu kỳ, nửa số cây cỏ: 22,9 fps;
    - thêm mặt đất đơn giản và trời không mây: 23,0;
    - hạ tiếp xuống 0,85x: 23,1.
  - Sau bước đầu, bớt tô màu không còn giúp gì: máy kẹt ở JS (~19 ms), HUD DOM (~10 ms) và phần trình chiếu.
  - Cùng cấu hình bỏ bóng / bỏ HDR / nửa cây cỏ mà ẩn thêm HUD DOM: 32,1 fps (khung giật dài từ 58% còn 26%). HUD tốn khoảng 12 ms mỗi khung trên máy này, nên trên máy yếu nó là bước lớn nhất sau khi đã giảm hình.
  - Cấu hình đó thành bản game ở Crash Ramp v100v: cờ máy rất yếu `crashramp.vweak`, do governor tự đặt; bỏ bóng, vẽ thẳng ra màn (không target HDR, không hậu kỳ), nửa cây cỏ; chỉ khi Settings để Tự động. Một lượt 128 giây trên đường, HUD DOM bật và ẩn xen kẽ mỗi 9 giây: có HUD 26,4 fps (37,9 ms, khung ≥37 ms 41%, update 5,0 + render 11,0 ms), ẩn HUD 39,2 fps (25,5 ms, 16%, 3,6 + 10,5 ms). Cao hơn lượt thử bằng công tắc bench (22,9 và 32,1), render JS 11 ms thay vì 15.
  - v100w chỉ ghi số trên HUD (xu, mét, km/h) 3 khung một lần. Bốn lượt xen kẽ V, W, V, W, có HUD: 26,3 lên 28,2 fps, khung ≥37 ms từ 40% còn 35%. Phần HUD (có trừ ẩn, trong cùng lượt) từ khoảng 14 ms còn 10-11 ms. Ẩn HUD hai bản như nhau (41,5 và 40,3 fps). Phần lớn chi phí HUD không nằm ở việc đổi chữ.
  - v100x (shader tự ra sRGB trên đường vẽ thẳng, shader biên dịch trước lượt chạy): fps như v100w (26,3 và 25,8, có HUD). Khung dài nhất trong 3 giây đầu lượt 119-135 ms thay vì 175-185 ms, không còn shader nào biên dịch trong lượt.
  - Luật rút ra từ v100x cho game three.js có hai đường vẽ (thẳng ra màn và qua composer HDR): mọi `ShaderMaterial` tự viết phải kết thúc bằng `#include <tonemapping_fragment>` và `#include <colorspace_fragment>` (vào target tuyến tính thì hai dòng này không làm gì). Thiếu chúng thì trên đường vẽ thẳng màu ra tối và đậm (Crash Ramp: bụi nâu sẫm, trời đậm hơn trên OPPO A15). Dịch shader trước (`compileAsync`) với target giống đầu ra thật: three dịch biến thể khác nhau cho màn hình và cho render target (Crash Ramp thấy 14 lần dịch ở đầu lượt cho tới khi sửa).
  - Ẩn từng phần HUD 4 giây, xen kẽ với 4 giây hiện đủ, so mỗi cửa sổ với cửa sổ hiện đủ ngay trước và sau nó (cùng đoạn đường): đồng hồ tốc độ, thanh động cơ, nút dừng, tay và chữ hướng dẫn, toast đều khoảng 0 ms. Khối trên (xu, mét, thanh tiến độ) 1-5 ms. Nút tên lửa 10-14 ms, toàn bộ là nhịp gợi ý `.hintp` (xem luật animation ở trên). Không có gợi ý, HUD còn khoảng 7 ms mỗi khung. Gộp HUD về một lớp (bỏ class `hudl`) chậm hơn khoảng 4 ms.
  - Cửa sổ ẩn/hiện phải tính theo thời gian chạy và lệch chu kỳ với độ dài lượt chơi. Chu kỳ 56 giây trùng lượt chạy khoảng 60 giây làm mỗi phần luôn rơi vào cùng một đoạn: ẩn thanh động cơ ra +3,6 ms, vô lý.
  - Bench không lưu (`nosave`) là người chơi mới mỗi lượt: gợi ý tên lửa chờ bấm nên bật 61% số khung. Số "có HUD" của bench như vậy gồm cả nhịp gợi ý.
  - Trên máy hạng này, hạ độ nét không đủ, phải bớt việc mỗi khung ở cả CPU lẫn GPU.
  - Đo fps của bất kỳ app nào không cần root: `adb shell dumpsys SurfaceFlinger --latency '<tên layer>'` (tên lấy từ `--list`; mỗi lần trả khoảng 127 khung gần nhất).
- **Target cảnh R11F_G11F_B10F thay half float:** nhanh hơn 2,1 ms, nhưng 82% điểm ảnh lệch, tối đa 6/255. Trời thành từng bậc (thấy rõ khi tăng tương phản). Đây là đổi hình, không phải tối ưu giữ hình.

Quy đổi nhanh trên Galaxy A16 (Mali-G68 MP2) ở 3x: 1 chu kỳ malioc mỗi điểm ảnh trên cả màn (2 triệu điểm ảnh) tốn khoảng 1,1 ms. Bầu trời khoảng 7 chu kỳ trên nửa màn là khoảng 3,7 ms, khớp số đo. "Đường dài nhất" của malioc tính cả nhánh của map khác (sao, hành tinh: 29 chu kỳ). Muốn biết đường thật của một map thì gấp các nhánh đó thành `false` trước khi chạy malioc.

**Làm được mà hình giữ nguyên** (mỗi cái đã so từng điểm ảnh):
- Gấp shader theo map: phép thử trên uniform không đổi trong cả map (biome, biển, sỏi, tuyết...) thay bằng `true` / `false` trong `onBeforeCompile`, thêm khoá vào `customProgramCacheKey`. Compiler bỏ hẳn nhánh không dùng: mặt đất Map 1 từ 76 xuống 54 chu kỳ.
- Pass hậu kỳ cuối ở `mediump`, giữ `highp` cho toạ độ texture (màn hơn 1024 điểm ảnh), sampler HDR, đồng hồ (giây từ lúc mở game) và hash. Ra 8 bit nên ảnh như cũ: 14.1 xuống 11.9 chu kỳ.
- Lớp màu có trọng số 0 thì bỏ qua cả phép tính (`if (w > 0.0)`); hash nhiễu đọc từ texture tính sẵn thay vì `sin` mỗi điểm ảnh.
- Bớt draw call (thời gian JS của three và driver trên mỗi lệnh): cảnh vật chia đoạn dọc đường thành một lệnh mỗi loại bằng `app.InstanceWindow` (khung chạy Map 1 từ 104 xuống 76 lệnh, Map 6 từ 88 xuống 44); mesh tĩnh cùng vật liệu gộp bằng `app.mergeParts`; cờ nhiều màu thành một geometry trắng với màu theo instance (1 × màu ra đúng màu cũ); đèn nhấp nháy theo nhóm thành một mesh mỗi nhóm.
- Bóng của cảnh tĩnh nướng sẵn vào mặt đất một lần khi dựng map; chỉ xe đổ bóng thời gian thực.
- Không gửi lệnh vẽ rỗng: bộ hạt chưa có hạt nào thì ẩn (`visible = false`), không để three vẽ 0 hạt. Crash Ramp v99l: mỗi khung có 2 lớp hạt rỗng, cả lượt chơi 2174 lệnh vẽ rỗng, sau sửa còn 0.

**Ánh sáng theo đỉnh (hình lệch rất ít, chủ dự án đã chọn).** Tính ánh sáng mặt đất và cảnh vật ở đỉnh thay vì ở từng điểm ảnh: A10 nhanh hơn khoảng 24%, ảnh lệch tối đa 33/255 trên 0,6% điểm ảnh, nhìn bằng mắt không thấy. Crash Ramp v99h bật cho mọi máy. Lần thử đầu (v98i) chỉ chuyển một phần ánh sáng nên không nhanh hơn; phải chuyển cả phần tính đèn của vật liệu, chỉ giữ ở điểm ảnh những gì đổi theo điểm ảnh (texture, sương mù).

**Đã thử, không nên làm lại:**
- `mediump` cho mọi fragment shader: A10 không nhanh hơn chút nào.
- Varying 16 bit (mediump) cho màu, ánh sáng, trọng số 0..1 của mặt đất và cảnh vật: malioc báo đường ngắn nhất giảm 17-20%, nhưng trên A16 ở 3x chỉ đỡ 0,4 ms trên 21 ms (2%). Ảnh lệch tối đa 3/255 trên 2,6% điểm ảnh. Rẻ nên vẫn để, nhưng đừng mong thêm fps.
- Bớt một nửa cây cỏ: không nhanh hơn (cảnh vật chỉ khoảng 10% điểm ảnh).
- Chỉ chuyển một phần ánh sáng sang đỉnh: 12.0 khung/giây như cũ (chuyển hết thì được, xem trên).
- Đổi màu mặt đất sang công thức nhẹ hơn: A10 không nhanh hơn (chi phí mặt đất là số điểm ảnh, không phải phép tính màu). Đừng dùng API mới hơn Chrome 80 trong bản thử (`String.replaceAll` có từ 85 làm bản thử trên A10 không vẽ gì).
- Gộp hậu kỳ vào vật liệu: nước, đèn, quầng sáng trộn trong HDR tuyến tính, nên hình khác.
- Gộp mặt đất thành một buffer: phải đẩy khoảng 30 MB lên GPU lúc mở map, máy 2 GB khựng. Mặt đất giữ mỗi đoạn một lệnh.
- Hạ độ phân giải, tắt bóng, tắt bloom: đổi hình, chỉ làm khi chủ dự án chọn, và theo luật độ nét tự động bên dưới.

**Kiểm chứng mỗi thay đổi "không đổi hình":** vẽ cùng một khung hai cách trên cùng một trang (đồng hồ cố định, camera cố định, hạt và chim tắt), lệch tối đa 1/255 trên mọi map, ở menu và lúc chạy; đếm `drawElements*` / `drawArrays*`, số lần đổi vật liệu và `useProgram` của một khung trước và sau; rồi fps trên A10 trước và sau. Trong kit: `node tools/gpu-audit.mjs draws | diff | shaders <url>` làm ba việc đầu khi trang (bản dev) đặt `window.__gpuAudit = { renderer, scene, render, freeze, toggles }`.

### Bớt việc CPU mỗi khung

Trên máy yếu, phần lớn thời gian JS mỗi khung là lệnh vẽ của three, không phải logic game. Galaxy A10 tốn khoảng 30 ms JS mỗi khung; profile CPU (máy tính, CPU chậm 6 lần cho giống A10) cho thấy render của three chiếm 26 ms, riêng đổi shader program 12 ms. Galaxy Tab A8 ở 1x: 16,8 ms JS, trong đó update của game 3,2 ms, 148 lệnh vẽ. Trước khi sửa, đếm `useProgram`, lệnh vẽ và lệnh GL của một khung (`tools/gpu-audit.mjs draws` ở trên).

Những việc giữ nguyên hình (Crash Ramp v99c, v99d, so từng điểm ảnh trên 6 map):
- Vật liệu trong suốt hai mặt (`side: DoubleSide`) bị three vẽ hai lần (mặt sau rồi mặt trước). Với vật liệu cộng sáng (`AdditiveBlending`), thứ tự không đổi kết quả: đặt `forceSinglePass = true`.
- Vật đổ bóng vẽ bằng instance: mỗi loại dùng chung một `customDepthMaterial` (`MeshDepthMaterial`). Không thì mỗi vật liệu có một program riêng trong pass bóng.
- Sắp vật đặc theo program trước, khoảng cách sau (`renderer.setOpaqueSort`). Vật trong suốt giữ thứ tự xa tới gần.
- Phần chỉnh màu không đổi trong cả map thì gấp vào shader hậu kỳ, như gấp shader mặt đất ở trên.
- Camera bóng chỉ bao những vật đổ bóng đang thấy, và dời theo đúng lưới texel của shadow map để bóng không rung.
- Gộp sẵn (bake) các vật nhỏ nhiều mảnh đứng yên: một mesh cho mỗi vật liệu + cách đổ bóng, mảnh gốc giữ ẩn nếu code cần vị trí của chúng (vòi phun, điểm bắn). Trên máy yếu mỗi lệnh vẽ tốn khoảng 0,1-0,2 ms CPU qua WebView/ANGLE. Crash Ramp v100u: bệ tên lửa từ 17 xuống 6 lệnh vẽ, hình như cũ (người thử báo lag trên OPPO A15).

Kết quả cộng lại của ba việc đầu (CPU chậm 6 lần, Map 1): `useProgram` giảm 26%, lệnh vẽ 4%, lệnh GL 5%; số lần tra program trong pass bóng từ 7,4 xuống 0,45 mỗi khung, pass bóng từ 1,41 xuống 1,01 ms.

Đừng bật tắt giữa lượt chơi những thứ làm đổi shader program (bóng, sương mù, loại vật liệu): A10 đứng khoảng 7 giây để dịch shader mới. Chọn lúc mở game, hoặc ở màn tải giữa hai lượt.

### Độ nét tự động: bắt đầu nét nhất, chỉ hạ khi chậm thật

Người chơi chê hình mờ nhiều hơn chê chậm vừa phải. Luật của Crash Ramp (v99e đến v99n), áp dụng cho game mới:

- Mở game ở đúng độ nét của máy (pixel ratio của màn, tối đa 3x), có bloom. Không đoán trước theo RAM hay tên máy rồi hạ sẵn.
- Chỉ đếm thời gian đang chơi: menu, màn tải, quảng cáo, lúc trang ẩn không tính.
- Chỉ hạ khi 15 giây liền, mỗi giây đều 30 khung/giây trở xuống. Một lần khựng (dịch shader, nạp map, GC) không bao giờ đủ để hạ.
- Hạ từng bậc một, mỗi bậc đo lại ít nhất 5 cửa sổ 1 giây đang chơi và 120 khung. Bậc thấp hơn phải nhanh hơn thật (ít nhất 8%) mới giữ; không nhanh hơn là máy nghẽn ở CPU, quay lại bậc cũ và thôi hạ. Đang đo một bậc thì không hạ tiếp.
- Máy dưới 10 khung/giây thì đo xong sau 12 cửa sổ dù chưa đủ 120 khung, để máy chỉ chạy 2-3 khung/giây không mất vài phút mới xuống được bậc vừa sức (v99n).
- Hai lần chậm cách nhau quá 5 giây (hết lượt, về menu) là hai đoạn riêng, không cộng dồn; số đo gốc của một bậc chỉ lấy các cửa sổ từ sau khoảng nghỉ cuối (ít nhất 5). Cộng dồn thì cuối lượt trước nhẹ cộng đầu lượt sau nặng làm bậc thấp hơn trông như không nhanh hơn: Galaxy Tab A8 với v99u không giữ được 1x, với v99v giữ 1x tới cuối (trung vị 20 khung/giây).
- Bậc 1.5x là sàn của máy bình thường. Máy vẫn 30 khung/giây trở xuống ở 1.5x mới xuống tiếp 1.25x rồi 1x (máy cỡ Galaxy A10).
- Lên lại bậc nét hơn khi số đo cho thấy bậc đó vẫn giữ được khoảng 36 khung/giây.
- Trình duyệt tự giới hạn 30 khung/giây (iPhone tiết kiệm pin, trang nhúng): đó không phải máy chậm, giữ nguyên độ nét (`onCap` của `createApp`).
- Giới hạn 30 khung/giây do chính game đặt khi máy nóng (mục dưới) cũng không phải máy chậm: lúc bị giới hạn, chỉ cửa sổ dưới 27 khung/giây mới tính là chậm.

Kết quả thật: Galaxy Tab A8 trung bình 19 lên 21,4 khung/giây, khung thấp nhất 9 lên 15 (v99l, sau khi bỏ lệnh vẽ rỗng và đo bậc lâu hơn để không nhảy qua lại). Galaxy A16 (Mali-G68) ở 2x có bloom khoảng 41 khung/giây, ở 3x khoảng 21: máy tầm trung 2024 không cần hạ dưới 2x.

### Máy nóng khi chơi lâu

Governor giữ GPU chạy 100% để có nhiều khung nhất, nên chơi lâu thì máy nóng. Galaxy A16 ở 1.5x: chip từ 32 lên 47,6 °C trong 3,5 phút mà Android vẫn báo trạng thái nhiệt `'none'`. Chỉ có ít khung hơn hoặc ít điểm ảnh hơn mới làm máy mát; tối ưu shader làm mỗi khung rẻ hơn nhưng governor lại dùng phần dư để vẽ nét hơn.

Số đo Crash Ramp v99x/v99z trên Galaxy A16 (2/11/2026; Chrome 156 qua `adb reverse`, game tự chơi 10 phút mỗi bài, bắt đầu khi chip 35 °C, máy đang sạc qua cáp):

| Bài | fps khi chạy (thấp nhất) | Mặt máy cao nhất | Android báo |
|---|---|---|---|
| 3x | 30,6 (21) | 40,1 °C | `'light'` ở phút thứ 10 |
| 3x khoá 30 | 23,6 (18) | 39,2 °C | `'none'` |
| 2x | 48,8 (31) | 38,4 °C | `'none'` |
| 2x khoá 30 | 28,7 (22) | 39,3 °C | `'none'` |

Chip lên 47-48 °C ở cả bốn bài. Vẽ ít điểm ảnh hơn vừa mượt hơn vừa mát hơn. Khoá khung trong một trang Chrome gần như không làm mát, vì Chrome vẫn ghép màn hình ở 90 Hz. Đo hiệu quả của khoá khung trong app, nơi `platform.device.setFrameRate` hạ được tần số màn hình, không đo trong trình duyệt.

Luật (Crash Ramp v99j, chủ dự án chọn "khoá 30 khung/giây, giữ nét"):
- `platform.device.thermal.status` từ `'light'` trở lên, hoặc `headroom` từ 0,6 trở lên: giới hạn lúc chơi ở 30 khung/giây, giữ nguyên độ nét và hiệu ứng.
- Mở lại khi máy mát liền 60 giây (`'none'` và `headroom` dưới 0,5, hoặc không biết headroom).
- Chỉ ở `'severe'` trở lên mới bỏ bớt hiệu ứng.
- Từ @horus/webgame 0.51.0 iOS cũng báo nhiệt (`ProcessInfo.thermalState`: fair, serious, critical thành `'light'`, `'moderate'`, `'severe'`; headroom luôn -1), nên cùng một đoạn code chạy cả hai nền tảng.

```js
let hot = false, coolSince = 0;
function onThermal() {
  const t = platform.device.thermal, now = performance.now();
  const warm = ['light', 'moderate', 'severe', 'critical', 'emergency', 'shutdown'].includes(t.status) || t.headroom >= 0.6;
  const cool = t.status === 'none' && t.headroom < 0.5;   // headroom -1 (không biết) cũng là mát
  if (warm) { hot = true; coolSince = 0; }
  else if (hot && cool) { if (!coolSince) coolSince = now; if (now - coolSince > 60000) hot = false; }
  game.setFpsCap(hot ? 30 : 60);                          // chỉ giới hạn lúc chơi; menu đã nhẹ
  game.setEffects(['severe', 'critical', 'emergency', 'shutdown'].includes(t.status) ? 'low' : 'full');
}
platform.on('thermal', onThermal);
setInterval(onThermal, 5000);                             // để đếm 60 giây mát khi không có sự kiện mới
```

Vì sao game Unity cùng loại thường mát hơn: Unity mặc định 30 khung/giây, độ phân giải thấp hơn 3x, thường không có HDR, bloom hay chỉnh màu, và vẽ thẳng bằng Metal/Vulkan. Game web vẽ WebGL qua lớp dịch sang Metal và WebView còn chép khung thêm một lần. Muốn mát như vậy thì giới hạn khung khi máy ấm, không phải hạ hình từ đầu.

### Mở game nhanh

- Đo từng bước của lần mở đầu trên người chơi thật trước khi sửa (sự kiện `boot`, bước 16). Crash Ramp v98a, 5 lần mở đầu thật 14-24 giây: dịch shader trước 4,9-9,9 giây, dựng map 2,5-5,5 giây, vẽ ảnh nhỏ của shop 1,7-3,2 giây.
- Chỉ dịch trước shader menu cần (Crash Ramp 36 trên 72 program), phần còn lại dịch nền sau khi menu hiện; dựng đoạn đường gần điểm xuất phát trước; ảnh nhỏ của shop làm sẵn lúc build (giống từng điểm ảnh) thay vì vẽ lúc mở game; thông tin app, cloud save, ngôn ngữ chạy song song; quảng cáo bắt đầu tải sau khung đầu của menu. Việc nền nhường khoảng 700 ms sau mỗi lần chạm để menu không khựng. Crash Ramp v98b, máy tính CPU chậm 4 lần: tới menu từ 4,76 xuống 3,47 giây.
- Máy không có `KHR_parallel_shader_compile` cũng hiện menu trước, rồi mới dịch phần còn lại (v98d): A10 tới menu từ 36 xuống 23 giây sau khi mở app.
- Mỗi tổ hợp vật liệu khác nhau là một shader program phải dịch trên máy ở lần mở đầu (Unity dịch sẵn lúc build). Gộp các vật liệu chỉ khác nhau ở tham số thành một program (kiểu thành uniform, khoá `customProgramCacheKey` chung): Crash Ramp v98x từ 37 xuống 32 program ở menu, hình như cũ. Đừng gộp những vật liệu thật sự khác nhau thành shader nhiều nhánh: rẻ lúc mở nhưng đắt mỗi khung trên máy yếu.
- Bắt đầu việc GPU sớm: tạo renderer, nướng texture nhiễu, dựng trời và môi trường của map đoán trước ngay sau khi gọi `platform.init`, song song lúc chờ save và Remote Config (Crash Ramp v98w). Đọc kết quả GPU (`readRenderTargetPixels`) bằng PBO và fence, không đọc chặn.
- Máy không có `KHR_parallel_shader_compile` (A10, máy ảo Test Lab) thì khung đầu phải trả hết các shader đã gửi; chỉ có cách gửi sớm để chồng lên thời gian chạy JS.
- Máy không có `KHR_parallel_shader_compile` thì không bao giờ để một khung dịch hết shader: Crash Ramp v101c, lần mở đầu (driver chưa có cache) trên máy 2 GB mất 8,3 giây ở khung đầu của menu và 9,4 giây ở cổng vào lượt đầu, màn tải đứng hình, máy PowerVR báo ANR trong `PVRUniFlexCompileToHw`. Việc GPU của WebView chạy trong tiến trình của app, nên một mẻ dịch vài giây chặn luôn khung hình của app. Cách làm: mỗi khung dịch một program, vẽ ấm một vật cho mỗi program mới vào một target 1x1 giống của cảnh, giữa hai lần có một khung trống, vừa làm vừa "cho ăn" watchdog của màn tải. Ghi số đo mỗi lần mở (thời gian khung `boot_bg`, cổng vào lượt, số program đã dịch).
- Thời gian mở game dao động theo độ bận của máy (5-7 giây giữa hai lần trên cùng máy): so hai bản cùng ngày, cùng máy, chạy xen kẽ, lấy trung vị nhiều lần. Bench mở game trên trang có thẻ viewport (trang không có viewport bị bố cục 980 px, chậm gấp 4).

### Đo cho đúng

- Một lần đo fps trên máy thật Test Lab tốn khoảng 10 phút quota, một lần đo mở game khoảng 3 phút; quota miễn phí 30 phút mỗi ngày nên lên kế hoạch từng lần chạy.
- Máy ảo Test Lab và Chrome headless (SwiftShader) không dùng để kết luận fps: chỉ dùng để kiểm game chạy hết lượt không lỗi. Kết luận fps bằng máy thật (A10 trong Test Lab, điện thoại cắm USB qua `adb reverse` với bench).
- So trong cùng một lần chạy (tỉ lệ giữa các biến thể), không so số tuyệt đối giữa hai ngày: nhiệt độ máy khác nhau.
- Bench chỉ đo lúc xe đang chạy và mỗi bậc ít nhất 45 khung; số đo lúc đứng yên ở menu làm bậc nào cũng trông nhanh.
- Mỗi bước của một lần đo chạy trên một đoạn đường khác: so hai cấu hình thì xen kẽ nhiều vòng (A, B, A, B... 8 vòng), không chạy A rồi B một lần.
- Thay đổi chỉ vài % thì đo trên đường chạy không thấy: trên A16, cùng một A/B ra +6% rồi -2% khi đảo thứ tự. Đo GPU trên một khung đứng yên:
  - mỗi lượt vẽ cùng một khung, trước hết 6 khung làm nóng, rồi 12 khung liền nhau với một `readPixels` 1 điểm ảnh ở cuối (không chờ GPU sau từng khung);
  - bản đồ bóng vẽ lại mỗi khung như lúc xe chạy;
  - thứ tự các lượt xoay vòng mỗi vòng, 16 vòng;
  - thêm một lượt giống hệt lượt gốc (A/A) để biết sai số: A16 ra khoảng 1%.
- Đừng đặt lượt nhẹ (vẽ rỗng) ngay trước lượt cần đo. GPU Mali hạ xung khi rảnh, nên lượt ngay sau đo chậm hơn khoảng 30%.
- Bench phải vẽ đúng như game. Crash Ramp từng gặp ba lỗi:
  - lượt GPU chiếu sáng mặt đất theo điểm ảnh trong khi game đã chiếu theo đỉnh, nên "mặt đất gần nửa khung" là sai (thật khoảng 20%);
  - canvas không có depth nên lượt "vẽ thẳng ra màn" rẻ hơn thật;
  - trang đo chiếm luồng chính nên phần cảnh dựng nền (cây xa) không bao giờ xong.
  Mỗi lượt, kiểm số lệnh vẽ và số tam giác giống lượt gốc.
- Trước khi tin số đo của các bậc độ nét, xem fps của cảnh đứng yên có giữ được 5 phút không. Ashlar tụt 20-40% sau 5 phút đứng yên ở cả bản cũ lẫn bản mới, nên bậc đo sau trông chậm hơn chỉ vì cảnh chậm dần.
- Máy đo phải yên: trong 60 giây trước và trong lúc đo, không build, không Gradle, không chương trình nào khác dùng quá 25% một lõi. Có thì bỏ lần đo đó.
- Thêm vật liệu làm đổi chuỗi `Math.random` (three dùng nó tạo uuid), nên hạt và mảnh vỡ ra khác giữa hai bản: tắt chúng khi so ảnh.
- Test Lab luôn báo renderer crash lúc dọn máy sau khi bài test đã xong: bỏ qua dòng đó.
- Đo nóng máy trên điện thoại cắm USB: mỗi 30 giây đọc `adb shell dumpsys thermalservice` (Thermal Status và nhiệt độ AP, SKIN, BAT). Trước mỗi bài chờ chip về dưới 35 °C. Mỗi bài ít nhất 10 phút, giữ cùng độ sáng và cùng tình trạng sạc. Mặt máy (SKIN) là con số người chơi cảm thấy.
- Chrome headless trên Windows bị hạ xung sau khoảng một phút. Trình duyệt chạy không cửa sổ (Playwright, Puppeteer headless) bị Windows coi là việc nền: sau 60-90 giây, power throttling (EcoQoS) cho nó chạy ở xung gốc thay vì boost, nên cùng một khung tốn khoảng 1,8 lần và số fps hay thời gian tải đo sau đó thấp hơn thật.
  - Ashlar, 2/11/2026 (i5-13400F, Windows 10, boost 4,6 GHz, gốc 2,5 GHz): một vòng JS cố định trong trang từ 51 lên 95 ms giữa giây 60 và 90; cùng vòng đó trong node thường thì phẳng; ghim trình duyệt vào lõi P không đỡ.
  - Dấu hiệu: trong CPU profile mọi hàm chậm gần cùng một tỉ lệ, còn heap, số lệnh vẽ, số tam giác và số vật thể phẳng.
  - Cách sửa: công cụ test mở trình duyệt thì tự tắt power throttling cho cây tiến trình của nó (`SetProcessInformation` `ProcessPowerThrottling`, tốc độ không bị hạ) và đặt lại mỗi 10 giây khi trình duyệt còn chạy. Không đổi gì toàn máy (power plan, `powercfg`, registry). Ví dụ: Ashlar `tools/qa/browser.mjs` `launch()` với `tools/qa/quiet/nopowerthrottle.ps1`; `launch({ boost: false })` giữ cách cũ của Windows.
  - Sau khi sửa: 300 giây ở 1x phẳng (bench 50-56 ms, script 2,0-2,1 ms mỗi khung); CPU chậm 16 lần 13,1 fps 30 giây đầu, 16,6 fps 60 giây cuối, script 42-47 ms phẳng.
  - Người chơi không bị: tab đang hiện ở trước không bị hạ xung kiểu này. Điện thoại chậm đi vì nóng, phần đó đã có luật nóng máy của Crash Ramp.
  - A/B chạy xen kẽ trên cùng máy với cùng độ dài vẫn so được với nhau; số tuyệt đối đo sau khoảng 60 giây trước khi sửa thì thấp hơn thật.

### Game online: tải và mạng yếu (Ashlar)

- Màn tiêu đề hiện ngay từ ảnh chụp sẵn, rồi mới tải 3D. Trong lúc người chơi đứng ở màn tiêu đề, tải trước file của vùng sẽ vào (quái, NPC, texture vùng, wasm dự đoán), sau file của chính màn tiêu đề, trước các mô hình vào sau.
- Đo thời gian tải bằng nhiều hồ sơ mạng (nhanh với CPU chậm 4 lần, mạng khoảng 300 KiB/s), lần đầu và lần sau, ít nhất 3 lần mỗi bản, lấy trung vị: một lần đo lần đầu dao động khoảng 15 giây.
- Art để trên CDN khác server game, có thử lại 4 lần và quay về server game khi CDN lỗi.
- Mạng yếu: đừng bỏ socket im lặng quá sớm (Ashlar từng bỏ sau 3 giây, người chơi Việt Nam vào server Los Angeles RTT khoảng 180 ms rớt liên tục). Bỏ sau khoảng 12 lần RTT, thử lại nhiều phút khi trang đang hiện, vào lại đúng chỗ từ save, trang ẩn thì không nối lại. Chi tiết trong `@horus/netplay`.
- Độ nét của game online theo cùng luật độ nét tự động ở trên.
- Vật thể rời tầm nhìn rồi quay lại phải được gắn lại hình (Ashlar, 3/11/2026). Với tầm nhìn theo bán kính (interest management), vật thể ra khỏi bán kính bị client bỏ và quay lại là một object MỚI với CÙNG id. Bảng hình vẽ theo id mà vẫn gắn hình cũ vào object cũ thì để lại một bóng ma đứng yên ở chỗ cũ, còn con quái thật thì vô hình: người chơi bị đánh bởi con quái không thấy.
  - Sửa: khi object đằng sau một id đổi, dựng lại hoặc gắn lại hình của nó (và chuyển aura, đèn, các rig khác theo id đó); bắt đầu mờ dần từ lúc vật thể rời đi (một mốc `leftAt`); xác vẫn là xác.
  - Đừng dùng mốc giả theo thời gian như `time - 40`: nó âm trong những giây đầu sau khi tải trang hay vào vùng, nên mờ dần không bao giờ bắt đầu. Ashlar bị nặng nhất trong 40 giây đầu sau mỗi lần vào vùng.
  - Kiểm: đi tới khi một đàn quái ra khỏi tầm nhìn, đi lại, đếm số đòn từ hình cũ hoặc vô hình (Ashlar: 104/189 trước, 0/181 sau); cả sau khi kết nối lại lúc có quái gần (10/11 hình cũ trước, 0/11 sau).
- Đòn đánh của chính mình phải thấy nhanh khi chơi online (Ashlar, 3/11/2026; Việt Nam vào server Los Angeles, RTT khoảng 185 ms). Online chậm hơn offline khoảng 370 ms: RTT 186 + đồng hồ vẽ trễ khoảng 100 + server chờ input 51-96 + vòng gửi 25 Hz khoảng 25. Đo từng phần trước khi sửa; bộ đếm "view lag" làm cho lag compensation (RTT + vẽ trễ + chờ + hộp thư) không phải độ trễ vẽ, đừng đọc nó như vậy.
  - Những cách bớt mà luật chơi giữ nguyên (đo trên đường giả 85/85 ms, rung ±6 ms): đọc socket mỗi khung, không theo nhịp gửi; đòn của chính nhân vật mình chơi lúc đọc snapshot, không theo đồng hồ vẽ trễ (các vật khác vẫn theo); vẽ đạn của mình ngay khung bắn rồi giao cho sự kiện sinh đạn của server (thấy đạn 712 xuống 340 ms); mục tiêu ngoài tầm thì đoán trước việc đi tới (đi ngay, vung khi tới tầm: 529 xuống 145 ms); server giữ dự phòng input 0-1 tick thay vì đệm cố định (bớt 15-20 ms chờ; kiểm không mất input trên đường xấu: Ashlar 0 mất ở rung ±28 ms, 60 giây giữ đánh và bấm liên tục); đừng lấy RTT ban đầu từ một pong trang giữ lại lúc đang tải.
  - Đòn cận chiến thấy trúng từ 627 xuống khoảng 500 ms. Phần còn lại chủ yếu là một vòng mạng; chỉ dời server hoặc đổi luật mới bớt được.
  - Đếm số lần vung đoán trước bị server từ chối. Phần lớn là bấm vào quái server đã giết. Với dự phòng input nhỏ, một cú bấm có thể rơi đúng tick cú vung trước kết thúc và server bắt đầu muộn một tick: cho trang một tick châm chước trước khi coi là bị từ chối, nếu không cú vung mờ đi rồi chơi lại muộn.
  - Đo trên Windows thì tắt power throttling cho trình duyệt headless (xem "Đo cho đúng").

### Nhẹ khi quảng cáo che game

Quảng cáo toàn màn hình là màn native đè lên WebView, nên trong lúc đó game không cần bộ đệm vẽ. Ngay trước `platform.ads.rewarded` / `platform.ads.inter`, nhả những gì dựng lại được; khi quảng cáo đóng (xong, lỗi, hay quá 2 phút mà vẫn chưa về) thì trả **đúng** pixel ratio và kích thước cũ, không thấp hơn, rồi vẽ ngay một khung. Cảnh, geometry, texture và bóng đã nướng giữ nguyên, không phải tải lại.

```js
// src/adlight.js
import * as THREE from 'three';
let light = null;
export function adLightOn(shell, game) {
  if (light) return;
  const r = shell.renderer, size = r.getSize(new THREE.Vector2());
  light = { pr: r.getPixelRatio(), w: size.x, h: size.y };
  game.disposePostTargets();                          // render target hậu kỳ (bloom...): tự dựng lại lần vẽ sau
  const sh = game.sun.shadow; if (sh.map) { sh.map.dispose(); sh.map = null; }   // shadow map thời gian thực, cũng vậy
  r.renderLists.dispose();
  game.audio.releaseMusic();                          // nhạc đã giải mã: phần lớn bộ nhớ nhả được trên máy yếu
  r.setPixelRatio(1); r.setSize(1, 1, false);         // false: giữ kích thước CSS, chỉ bỏ bộ đệm vẽ
}
export function adLightOff(shell, game) {
  if (!light) return;
  const r = shell.renderer;
  r.setPixelRatio(light.pr); r.setSize(light.w, light.h, false);   // đúng như trước quảng cáo
  light = null;
  game.audio.restoreMusic();
  game.drawNow();                                     // một khung ngay, trước khi game hiện lại
}
```

Màn hình xoay trong lúc quảng cáo thì cho qua hàm resize của game với pixel ratio cũ. Crash Ramp v97g đo trên máy ảo Android: renderer WebView từ 236 MB xuống 145 MB trong lúc quảng cáo, sau đó về đúng 771×1371 ở pixel ratio 1.25, khung đầu sau 18 ms. Trên điện thoại thật còn nhả thêm bộ nhớ GPU của canvas, render target và shadow map.

Máy RAM 4 GB trở xuống còn nhả thêm bản GPU của hình khối và texture đã nạp của cảnh (`geometry.dispose()`, `texture.dispose()` trên đồ trong cảnh, không đụng texture của render target): three tự gửi lại ở lần vẽ sau, hình y hệt từng pixel. Phần này nhỏ (khoảng 12 MB một map của Crash Ramp v101c) nhưng cộng thêm với bộ đệm vẽ 1x1 và render target hậu kỳ đã nhả.

Khi quảng cáo đóng, gọi `adLightOff` trong `try/catch` rồi mới tới callback trao thưởng: vẽ lại khung lỗi (GPU yếu, context vừa mất) không được làm mất thưởng người chơi đã xem (Crash Ramp v98a).

**Xong khi:** chế độ thiết bị của Chrome (Moto G4, CPU chậm 4 lần) vẫn chơi được; `shell` báo tier không lên quá 2 khi đứng yên ở menu; một lần khựng ngắn lúc chơi không làm hạ độ nét; giả `'thermal'` `'light'` thì lượt chơi giới hạn 30 khung/giây mà độ nét giữ nguyên; đếm lệnh vẽ của một khung không có lệnh nào vẽ 0 phần tử, không vật liệu cộng sáng nào vẽ hai lần; trang chạy trên Chrome 81 không lỗi; sau một quảng cáo giả, `renderer.domElement.width` và `height` bằng đúng trước đó.

## 6. Vòng chơi

Một lượt có các trạng thái rõ ràng, mỗi trạng thái một hàm vào và ra: `menu` (ná, thẻ nâng cấp, nút shop) → `aim` (kéo ná) → `run` (xe chạy, camera bám) → `result` (thẻ kết quả: mét, tiền, x2) → về `menu` hoặc sang map sau.

Luật của Crash Ramp:
- Lượt đầu tiên của người mới phải đi được khoảng 25 đến 35% map và nhận đủ tiền mua 1 đến 2 nâng cấp. Người chơi phải thấy mình tiến bộ sau mỗi lượt.
- Lượt hướng dẫn chỉ cho thấy những gì game thật có (Crash Ramp v100m, 3/11/2026). Bản v98p-v98s cho lượt đầu đâm vào một bức tường phuy dựng riêng rồi nổ tung, màn kết quả có dòng "Crash bonus"; game thật không bao giờ nổ xe, lượt thường kết thúc vì xe hết đà trên dốc. Người chơi vừa chờ một trải nghiệm không bao giờ tới, vừa học sai vòng chơi (tưởng lượt kết thúc vì đâm, không phải vì xe còn yếu). Bản sửa: lượt đầu kết thúc như mọi lượt (hết đà, "SO CLOSE"), cùng số xu, dòng thưởng đổi thành "First run bonus"; cái kết cũ vẫn bật lại được bằng Remote Config.
- Bỏ một cái kết dựng sẵn thì đo lại khoảng cách bằng máy tự lái: lượt hướng dẫn có món miễn phí (tên lửa) có thể đi xa ngang lượt 2 đã nâng cấp, và bài học "nâng cấp thì đi xa hơn" mất. Crash Ramp Map 1 (econ 2): tên lửa 1 s cho lượt 1 tới 188 m, lượt 2 (Xe + Ná Lv 1, tên lửa) 190 m; tên lửa của lượt hướng dẫn cháy 0,6 s thì lượt 1 dừng ở 168 m, lượt 2 hơn khoảng 22 m.
- Tiền một lượt: `mét × pay × hệ số Income` cộng thưởng kỷ lục (phần mét vượt kỷ lục cũ × 50%) cộng thưởng về đích (lần đầu đủ, lần sau 15%).
- Về đích map thì mở map sau: xe mới, đường dài hơn, giá và pay cao hơn (bước 7).
- Nút tạm dừng trong lượt, và mọi thao tác chạm được bằng một ngón cái.

```js
// tiền một lượt (config.js)
export function runPayout({ idx, dist, best, finished, firstClear, mult }) {
  const rate = PAY_PER_M[idx], base = Math.floor(dist * rate);
  const record = best > 0 ? Math.floor(Math.max(0, dist - best) * rate * 0.5 * mult) : 0;
  const clear = finished ? Math.floor(clearBonus(idx) * (firstClear ? 1 : 0.15)) : 0;
  return { base, income: Math.floor(base * mult) - base, record, clear, total: Math.floor(base * mult) + record + clear };
}
```

**Xong khi:** chơi 5 lượt liền trên trình duyệt: mỗi lượt có thẻ kết quả, tiền cộng đúng, lượt sau đi xa hơn khi đã nâng cấp.

## 7. Kinh tế: giá, nâng cấp, map

Giá nâng cấp là đường mũ có làm tròn kiểu shop:

```js
import { economy } from './sdk.js';
const priceM1 = economy.priceCurve({ base: M1.priceBase, growth: M1.priceGrowth, round: economy.ROUNDING.even });
priceM1(0);   // 60
priceM1(5);   // ~384, làm tròn số chẵn
```

Crash Ramp: Map 1 giá 60 × 1,45 mỗi cấp, pay 0,14 xu/m, bắt đầu với 60 xu; các map sau giá và pay nhân theo map (map 2 khó hơn map 1, map 3 bằng map 1, map 4 khó hơn map 2, map 5 bằng map 2, map 6 khó hơn map 4: nhịp khó, nghỉ, khó hơn). Nút **BEST BUY** sáng trên thẻ nên mua: `economy.bestBuy(cands, { coins })` với `cands = [{ id, lv, cost }]`.

Trước khi chốt số, chạy mô phỏng cho 3 kiểu người chơi (không xem quảng cáo, thỉnh thoảng xem, xem nhiều) bằng `economy.simulateEconomy` trong Node (`horus-logic.mjs`). Mục tiêu của Crash Ramp: Map 1 khoảng 8 đến 12 phút, mỗi map sau lâu hơn một chút; ba kiểu người chơi chênh nhau cùng một tỉ lệ ở mọi map; không có map nào người không xem quảng cáo bị kẹt quá 3 lượt không mua được gì.

```js
// tools/sim.mjs (node tools/sim.mjs)
import { economy } from '../horus-sdk/horus-logic.mjs';
const res = economy.simulateEconomy({ maps: 6, upgrades: ['sling', 'car', 'income'], run, pay, pick, start: { coins: 60 } });
console.log(economy.economyReport(res));
```

Khi đổi đường giá hay pay sau khi đã có người chơi: tăng `ECON_VERSION` trong config và để `save.createSaveStore({ economy: { version, reset } })` cho bản lưu cũ làm lại tiền và nâng cấp (giữ cài đặt, mua hàng).

**Xong khi:** `node tools/sim.mjs` in bảng 3 kiểu người chơi × 6 map, đạt các mục tiêu trên; người dùng xem và đồng ý con số.

## 8. Quảng cáo rewarded

Mỗi chỗ mời xem một placement. Nút chỉ sáng khi có quảng cáo; bấm lúc đang tải thì chờ tối đa 3 giây rồi báo "chưa có video".

```js
import { platform, monetize } from './sdk.js';

async function rewarded(placement, give) {
  if (platform.ads.busy()) return;                             // chạm lần hai khi quảng cáo đang mở: không làm gì cả
  track('rv_offer', { pl: placement });                       // mỗi lần nút hiện ra
  if (!platform.ads.ready().rv) {
    const r = await monetize.waitRewarded(platform.ads, { waitMs: ADS.rvWaitMs, gone: () => game.state !== 'result' });
    if (r !== 'ready') { toast(t('ads_no_video')); track('rv_unavailable', { pl: placement }); return; }
  }
  S.adPend = { pl: placement, coins: placement === 'x2_coins' ? S.lastRunCoins : 0 };   // thưởng cần trả nếu trang bị tắt
  store.save(S);                                               // hệ điều hành có thể đóng trang lúc quảng cáo chạy
  track('rv_start', { pl: placement });
  adLightOn(shell, game);                                      // bước 5
  const r = await platform.ads.rewarded(placement);
  if (r.reason === 'busy') return;                             // quảng cáo trước còn đang chạy: để nó tự trả lời
  adLightOff(shell, game);
  delete S.adPend;
  if (!r.ok) { track(r.reason === 'closed' ? 'rv_cancel' : 'rv_fail', { pl: placement, why: r.reason }); return; }
  monetize.noteRewarded(S.ads, Date.now());
  give(); store.save(S); track('rv_done', { pl: placement });
}
platform.on('ads', (s) => ui.setAdButtons(s.rv));
```

**Mỗi lúc một quảng cáo.** Người chơi chạm hai, ba lần liền vào nút quảng cáo (30-70 ms) thì lần chạm sau gọi quảng cáo lần nữa khi cái đầu đang mở. Trước SDK 0.26.1 app trả lần sau là `not_ready`; game coi đó là "không có quảng cáo", trả lại bộ đệm vẽ, cảnh 3D và nhạc ngay dưới video đang chạy, và WebView crash trong `draw_gl` (Crash Ramp 2/11/2026: crash nặng đầu tiên trên Crashlytics, cùng một người chơi ba lần dưới video Unity Ads). Từ SDK 0.26.1 lần gọi sau trả ngay `{ ok: false, reason: 'busy' }` (interstitial: `{ shown: false, busy: true }`), không hỏi app, và analytics có `ad_dup` `{ pl, kind }`. Game kiểm `platform.ads.busy()` trước mọi việc trong hàm bấm nút, và gặp `busy` thì không đổi gì: không trả bộ đệm vẽ, không bật nhạc, không xoá `S.adPend`.

Android có thể tắt trang web trong lúc quảng cáo thưởng đang chạy (máy RAM thấp): người chơi xem hết mà callback không bao giờ về, trang mở lại ở menu. Từ SDK 0.22.0, app giữ những lần đó trong `platform.ads.lost` (`[{ pl, at }]`, web là `[]`). Game trao thưởng mỗi lần đúng một lần ngay sau khi đọc save, rồi gọi `lostDone()`:

```js
function recoverLostAds(game) {
  const lost = platform.ads.lost || [], pend = S.adPend;
  delete S.adPend;
  for (const { pl } of lost) {
    if (pl === 'x2_coins') game.addCoins(pend?.pl === pl ? pend.coins : S.lastRunCoins);   // lượt đã mất: số xu ghi trước quảng cáo
    else if (pl === 'shop_gems') game.addGems(GEMS_PER_VIDEO);  // như một video thường
    else (S.adCredit ||= {})[pl] = 1;                           // quà chưa trao: lần sau ở chỗ đó miễn xem quảng cáo
    track('ad_reward_recovered', { pl });
  }
  store.save(S);
  if (lost.length) platform.ads.lostDone();
}
```

Không bao giờ cho gem ở chỗ vốn không cho gem. Crash Ramp: một người chơi Galaxy A17 mất thưởng hai lần như vậy rồi gỡ game sau 27 giây.

Các chỗ của Crash Ramp: **x2 xu** trên thẻ kết quả (lượt đầu cho miễn phí để người chơi biết nút), **nâng cấp miễn phí** khi thiếu xu (bước 9), **1 gem** trong shop (1 video = 1 gem, không chờ), **rocket miễn phí** trước lượt, **x2 quà quay lại**. Gọi `platform.ads.load('rv')` khi thẻ kết quả mở và khi về menu.

**Xong khi:** trên trình duyệt với `platform.ads.simulate(...)`, mọi nút rewarded chỉ thưởng khi xem hết, đóng sớm không thưởng; analytics có `rv_offer`, `rv_start`, `rv_done` cho từng placement.

### Quảng cáo thưởng xong thì Android tắt luôn cả app (máy 2-4 GB)

`platform.ads.lost` chỉ gồm lần trang web chết mà app còn sống. Crash Ramp v101c đo trên người chơi thật: máy 2-4 GB cứ khoảng 10 quảng cáo thưởng thì một lần kết thúc bằng app bị tắt hẳn (`platform.device.exits` ghi `reason: 'low_memory'`), người chơi xem xong mà không được thưởng. Game tự giữ phần thưởng qua lần mở sau:

1. Ngay trước `platform.ads.rewarded`, ghi vào save một dòng ghi nhớ: placement, thưởng gì, lúc nào (lưu ngay, không đợi lần lưu sau).
2. Quảng cáo kết thúc bình thường (được thưởng hay bỏ giữa chừng): xoá dòng đó và lưu ngay.
3. Lần mở sau, đọc save xong: dòng ghi nhớ còn đó và `platform.device.exits` có một lần hệ thống tắt app (`low_memory` hay kiểu tắt khác của hệ thống, không phải người chơi tự đóng) từ 5 giây tới 10 phút sau lúc quảng cáo bắt đầu, thì trả thưởng đúng một lần rồi xoá dòng ghi nhớ.

Không bao giờ trả tiền cao cấp (gem) kiểu này: chỉ quảng cáo xem hết thật mới được trả gem. Xu, lượt chơi lại, x2 phần thưởng thì được.

## 9. Thiếu xu: bậc gem và quảng cáo

Khi người chơi bấm một thẻ nâng cấp không đủ xu, thẻ đó cho mua bằng quảng cáo hoặc gem theo bậc (`monetize.createShortLadder`). Luật Crash Ramp (theo mỗi lần vào menu): giá gem 1, 2, 3...; vào menu với 0 gem thì bậc đầu là xem quảng cáo, rồi 1, 2, 3 gem; có 1 gem thì 1 gem, quảng cáo, 2, 3; có hơn 1 gem thì không mời quảng cáo nữa.

```js
const ladder = monetize.createShortLadder(SHORT);      // SHORT là object sống trong config: Remote Config đổi được
const v = ladder.view(S.runs);                          // { open, step, gems, ads, prog }
if (v.open && v.ads) showFreeUpgradeButton();           // "Xem quảng cáo: nâng cấp miễn phí"
else if (v.open && v.gems) showGemButton(v.gems);
// mua xong: ladder.bought(id, 'coin' | 'gem' | 'ad'); xem xong: ladder.adWatched(S.runs)
```

**Xong khi:** với 0, 1 và 5 gem, thứ tự nút hiện ra đúng như luật trên; mua bằng gem trừ đúng gem, `an.spend('gem', ...)` được gửi.

## 10. Interstitial

Chỉ ở một chỗ: khi rời thẻ kết quả về menu, và chỉ khi mọi luật cho phép:

```js
const { due } = monetize.interDue(S.ads, ADS, {
  now: Date.now(), runs: S.runs, noAds: S.noAds, x2Skipped: x2Offered && !x2Taken,
  sinceStart: (Date.now() - sessionStart) / 1000, block: firstSession && !S.cleared[0],
});
if (due && platform.ads.ready().inter) {
  monetize.noteInter(S.ads, S.runs, Date.now());
  track('inter_show', { pl: 'result_exit' });
  await platform.ads.inter('result_exit');
}
```

Luật Crash Ramp: chỉ khi thẻ đã mời x2 mà người chơi không lấy; không trước lượt thứ 4; cách ít nhất 2 lượt và 120 giây; không trong 90 giây đầu phiên; không trong 45 giây sau một rewarded; phiên đầu không có cho tới khi qua Map 1. Đã mua Remove Ads thì không bao giờ có.

**Xong khi:** chơi 15 lượt liền không xem x2: interstitial ra đúng nhịp; mua Remove Ads (giả lập): không còn interstitial, rewarded vẫn có.

## 11. Lưu game

Một kho lưu cho cả game, có phiên bản, gộp ghi, bản dự phòng trong app:

```js
// src/save.js
import { platform, save, monetize, liveops } from './sdk.js';
export const ECON_VERSION = 1;
const defaults = () => ({
  coins: M1.startCoins, gems: GEMS.start, upg: { sling: 0, car: 0, income: 0 }, map: 0, unlocked: 1, cleared: [0, 0, 0, 0, 0, 0],
  best: {}, runs: 0, playMs: 0, noAds: false, buys: [],   // playMs: game tự cộng thời gian chơi
  settings: { sfx: true, music: true, haptics: true, notif: true, lang: '' },
  ads: monetize.pacingState(), offers: { last: -999, o: {} },
  meta: liveops.createMeta(), daily: liveops.createCalendar(), missions: liveops.createMissions(), notify: liveops.createNotify(),
  an: { ftue: {}, counts: {}, log: [] }, econ: ECON_VERSION,
});
export const store = save.createSaveStore({
  key: 'mygame.v1', defaults, mirror: (json) => platform.save.mirror(json),
  economy: { version: ECON_VERSION, reset: (d, f) => Object.assign(d, { coins: f.coins, upg: f.upg, map: 0 }) },
});
export const further = save.further('runs', 'playMs');   // bản nào chơi nhiều hơn thì đi xa hơn
```

Lưu thường (`store.queue(S)`) sau mỗi thay đổi nhỏ; lưu ngay (`store.save(S)`) sau khi mua hàng, trước khi hiện quảng cáo và khi về menu; `platform.on('pause', () => store.flush())`.

**Xong khi:** mua nâng cấp, tải lại trang: còn; xoá localStorage nhưng giữ bản mirror (giả lập `platform.save.backup`): tiến độ quay lại.

## 12. Mua trong app và shop

```js
import { platform, save } from './sdk.js';

function grant(p) {                       // p: { sku, token, orderId }
  const item = productBySku(p.sku);
  if (!item) return;
  if (!S.buys.some((b) => b.token === p.token)) {
    giveGoods(S, item);                   // gem, noAds, gói offer
    S.buys.push({ sku: p.sku, id: item.id, token: p.token, t: Date.now() });
    store.save(S);                        // lưu trước
    platform.an.earn('gem', item.gems || 0, 'iap');
  }
  platform.iap.finish({ sku: p.sku, token: p.token, orderId: p.orderId, consumable: !item.once, usd: item.usd });   // finish sau
}
async function buy(sku) {
  const r = await platform.iap.buy(sku);
  if (r.status === 'ok') grant(r);
  else if (r.status === 'pending') toast(t('shop_pending'));
}
export const merge = (into, from) => save.mergePurchases(into, from, { credit: (s, b) => giveGoods(s, productBySku(b.sku)), flags: ['noAds'] });
```

Giá hiện trên nút: `platform.iap.price(sku) || item.price`. Shop của Crash Ramp: 6 gói gem (10, 30, 100, 150, 200, 500 gem; $2.99 đến $29.99), Remove Ads $4.99, 1 gem cho mỗi video. Có nút **Restore purchases** khi `platform.iap.restorable`.

**Xong khi:** mua giả lập từng SKU: hàng vào đúng một lần; tải lại giữa chừng (trước `finish`): `pending()` giao lại, không trùng; `status: 'invalid'` không thưởng.

## 13. Offer

Bốn offer của Crash Ramp, luật bằng `monetize.due / shown / bought / openOffers` trên `S.offers`:

| Offer | Khi nào | Có gì | Giá |
| --- | --- | --- | --- |
| Starter | qua Map 1 hoặc lượt 12, mở 48 giờ, một lần | 60 gem, 5 rocket, tiền 5 lượt | $6.99 |
| Remove Ads | ngay sau interstitial thứ 3 trong ngày, tối đa 1 lần/ngày, 3 lần tổng | bỏ interstitial + 10 gem | $4.99 |
| Upgrade | 3 lượt liền không vượt kỷ lục (kẹt), mỗi 24 giờ | 3 gem, tiền 4 lượt | $0.99 |
| Season | đầu mỗi vòng map mới, mở 72 giờ | 30 gem, 10 rocket, tiền 8 lượt | $4.99 |

Chung: không popup trong 5 phút đầu phiên đầu, cách nhau ít nhất 3 lượt; offer đang mở có chip đếm ngược ở menu và dòng trên cùng của shop. "Tiền N lượt" tính theo map người chơi đang ở, để gói có giá trị như nhau ở mọi map.

```js
const st = monetize.offerState(S);
const d = monetize.due(st, OFFER_DEFS, OFFER, { now: Date.now(), runs: S.runs, day: liveops.dayKey() });
if (d) { monetize.shown(st, OFFER_DEFS.find((o) => o.id === d.id), OFFER, ctx); ui.offerPopup(d.id); track('offer_show', { id: d.id, why: d.trigger }); }
```

**Xong khi:** đổi giờ giả lập (`liveops.clock`), mỗi offer bật đúng lúc, đếm ngược đúng, mua một lần thì không hiện lại.

## 14. Remote Config

Mọi object trong `config.js` ghi đè được bằng khoá `<nhóm>_<khoá>`:

```js
import { monetize } from './sdk.js';
export function applyRemoteConfig(rc) {
  monetize.applyConfig({ ads: ADS, short: SHORT, offer: OFFER, m1: M1, notif: NOTIFY }, rc, new URLSearchParams(location.search));
}
```

Trên trình duyệt thử bằng query: `?ads=interEvery:3,interCooldown:60`. Giá trị Remote Config luôn là chuỗi; code luôn có mặc định.

**Xong khi:** `?ads=interFromRun:1` làm interstitial ra từ lượt 2; mọi khoá dùng có trong `remoteConfig` của `horus-game.json`.

## 15. Giữ chân: quà, nhiệm vụ, thu nhập khi vắng, thông báo

Dùng `liveops` thay vì tự viết đồng hồ và ngày:
- Phiên và ngày: `liveops.bootMeta(S.meta)` lúc mở, `liveops.resumeSession` / `pauseSession` theo `platform.on('resume' | 'pause')`.
- Quà 7 ngày: `liveops.calendarInfo` / `claimCalendar`. Nhiệm vụ ngày: `ensureMissions`, `missionProgress` (gắn vào `onTrack` của analytics), `claimMission`.
- Thu nhập khi vắng: `accrueOffline` / `claimOffline` (x2 bằng rewarded).
- Quà quay lại sau 7 ngày vắng: `liveops.giftDue`.

Thông báo local (Crash Ramp v2): tuần đầu tối đa 3 lần/ngày, đặt trước giờ người chơi hay mở game 15 phút, không trước 8:00 hay sau 22:00, rồi 1 lần/ngày tới ngày 14, rồi ngày 16, 18, 21, 24, 27, 30. Bỏ qua 9 lần liền thì chỉ 1 lần/ngày. Tiêu đề viết hoa, nội dung nói đúng thứ đang chờ (nâng cấp mua được, quà, kỷ lục).

```js
const plan = liveops.planNotifications({ now: Date.now(), starts: S.meta.hours, ignored: S.notify.ignored, config: NOTIFY, candidates, text });
platform.notif.schedule(liveops.toReminders(plan));
S.notify.plan = liveops.planRecord(plan);
// lúc mở lại: quay lại trong 4 giờ sau một thông báo cũng là phản hồi; thông báo tắt trên máy thì không đếm bị bỏ qua
const st = await platform.notif.state();
liveops.noteReturn(S.notify, Date.now(), platform.notif.opened?.kind || '', { respond: 240, enabled: !st.supported || st.enabled });
```

Xin quyền: `platform.notif.ask()` sau lượt thứ 2 (không ngay khi mở game; hỏi muộn thì phần lớn người chơi đã bỏ game trước khi được hỏi). Lập lại lịch mỗi lần `pause`. Thông báo có tiếng riêng lấy từ âm thanh có sẵn trong game (người chơi nghe là nhận ra game nào): `notif { sound: "sfx/notify.wav", headsUp: true }` trong `webgame.config.json`; Android nhắc bằng alarm nên Doze không nuốt.

Chia sẻ, mời bạn, mã quà (Crash Ramp v89):
- Nút Share ở màn kết quả: vẽ ảnh kết quả bằng canvas rồi `platform.share({ title, text, url, image })` (Android chooser, iOS share sheet, web `navigator.share` hay chép link). Link thách đấu để trong Remote Config.
- "Mời bạn": chỉ link, không thưởng (thưởng theo lượt mời là chỗ gian lận).
- "Mã quà": `liveops.redeemCode(S.codes, mã, rc.gift_codes, { caps: { coins: 2000, rockets: 5 } })`; bảng mã rỗng mặc định, mỗi người một lần, không bao giờ gem, trần kẹp trong code để Remote Config sai không làm lạm phát.

**Xong khi:** `platform.notif.schedule` được gọi khi ra nền với danh sách trong khung giờ; tắt Notifications trong Settings thì `cancelAll()`.

## 16. Analytics và phễu người mới

```js
import { liveops, platform } from './sdk.js';
export const FTUE_STEPS = ['open', 'first_pull', 'first_launch', 'first_result', 'first_x2', 'first_upgrade', 'run_2', 'run_5', 'map1_clear'];
const an = liveops.createAnalytics({
  state: S.an, steps: FTUE_STEPS, installAt: () => S.meta.installAt, build: GAME_BUILD,   // GAME_BUILD trong config.js ('v90'): tham số build trên mọi event
  ctx: () => ({ map: S.map, runs: S.runs, day: liveops.dayIndex(S.meta) }),
  sink: { log: (n, p) => platform.an.log(n, p), user: (p) => platform.an.user(p) },
});
export const track = (n, p) => an.track(n, p);
```

Sự kiện tối thiểu: `boot` (`ms` từ lúc mở tới khi chơi được), `run_start`, `run_end` (map, mét, tiền, thắng/thua: kèm `platform.an.result(won)`), `upgrade` (id, cấp, trả bằng gì), `map_clear`, mọi bước FTUE, `rv_offer` / `rv_start` / `rv_done` theo placement, `inter_show`, `offer_show` / `offer_buy`, `shop_open`. Tiền: `platform.an.earn` / `spend` mỗi lần nhận hay tiêu, `platform.an.balance` sau đó. Doanh thu quảng cáo và IAP do app tự gửi.

Để biết máy nào chậm hay lỗi (Crash Ramp v97f, v97g):
- `boot` thêm `wv` (số Chrome của WebView; iOS là phiên bản iOS), thời gian từng bước mở game (`t_js`, `t_plat`, `t_cloud`, `t_game`, `t_world`, `t_pre`...; -1 = không chạy) và `hid` (trang bị ẩn lúc mở: bỏ khỏi thống kê thời gian). Lần mở đầu trên máy yếu mất 15 đến 70 giây; các bước này cho biết vì sao.
- `boot_fail` với `stage` (`init` = chưa có WebGL, `load` = map đầu lỗi).
- `js_error` {`msg`, `at`}: tối đa 3 lần mỗi phiên.
- `gl_lost` {`map`, `ld` đang nạp, `hid`, `mem`}, `load_slow` (nạp map quá 15 giây, kèm từng bước), `load_fail` (watchdog bước 5).
- `ad_reward_recovered` {`pl`} (bước 8).
- User property `webview` để chia mọi chỉ số theo phiên bản WebView.

Robot không phải người chơi: máy Firebase Test Lab, báo cáo trước khi ra mắt của Play và máy ảo Android chạy bản release có `platform.device.robot = true`; vỏ app tự chặn tracking và quảng cáo thật trên đó (webgame 0.33.0, máy ảo từ 0.40.0). Khi đọc số liệu vẫn lọc máy của team và robot: ở Crash Ramp, 74 trên 119 "người chơi" ngày đầu là robot của Google.

**Xong khi:** chơi 3 lượt, mọi bước FTUE đã đi qua đều có trong `an.state.ftue`; mọi event có `build`; tên sự kiện và tham số chữ thường, phẳng.

## 17. Settings, hỗ trợ, ngôn ngữ, màn hình

Settings có: âm thanh, nhạc, rung, thông báo, ngôn ngữ, **Contact support** (`platform.support.contact({ to: 'support@horusvn.com' })`), mã hỗ trợ (`platform.support.id`), dòng cloud save (`cloud.statusText(await platform.cloud.status())`), **Privacy Policy** (mọi vùng, mục dưới), **Privacy settings** khi `platform.ads.hasPrivacy`, **Restore purchases** khi `platform.iap.restorable`, phiên bản app.

### Quyền riêng tư: consent, Google DMA, Privacy Policy ở mọi vùng

- **Consent và Google DMA.** Ở vùng GDPR (EEA, Anh, Thuỵ Sĩ), app hiện form consent của Google (UMP, qua MAX) lúc mở lần đầu. Lựa chọn của studio (3/11/2026): mọi SDK tiếp tục đo và chia sẻ dữ liệu, kể cả khi người chơi không đồng ý. Từ app build bằng webgame 0.54.0, Adjust gắn consent DMA của Google (đọc từ câu trả lời UMP) vào lượt cài và mọi event; Adjust luôn đếm lượt cài và doanh thu. Facebook không chờ consent: đây là đánh đổi GDPR đã biết, do publisher chọn, game sau có thể quyết khác. Người chơi đổi ý qua "Privacy settings" thì Adjust nhận câu trả lời mới. Game không phải viết gì cho việc này; đừng tự thêm SDK gửi dữ liệu cho bên thứ ba. Hộp Terms/Privacy Policy của MAX (nút CONTINUE) hiện cho mọi người chơi ngoài GDPR ở lần mở đầu, và MAX chỉ báo khởi động xong sau khi bấm: lượt cài Adjust chờ tới lúc đó, đúng như doc của MAX (khởi động MMP và analytics sau flow) và Adjust (first session delay). Người tắt app trước khi bấm thì lần đó chưa là lượt cài, lần mở sau mới tính; so lượt cài Adjust với Play sau bản phát hành đầu trên webgame 0.54.0 (chủ dự án chọn giữ như doc MAX, 3/11/2026).
- **Số liệu UA sau consent.** Tổng lượt cài và doanh thu không lệch (Adjust đếm đủ; MAX, AdMob, store không đổi). Chỉ camp Google ở EEA lệch: người chơi không đồng ý đến từ Google Ads có thể không được Google nhận, hiện là Organic trên Adjust; Google tự ước lượng phần thiếu nhờ cờ DMA. Đọc camp Google ở EU bằng cách so Adjust với Play Console và xem sự kiện `consent_state` (tỷ lệ đồng ý thật). Muốn tăng tỷ lệ đồng ý thì chỉnh form GDPR trong AdMob > Privacy & messaging (publisher quyết). Không bao giờ gửi `ad_user_data=1` cho người đã từ chối: vi phạm EU User Consent Policy của Google. Chi tiết: README của webgame, mục "Consent và Google DMA".
- **Link Privacy Policy trong Settings, ở mọi vùng.** Nút "Privacy settings" chỉ có ở vùng GDPR (`platform.ads.hasPrivacy`), không thay được link này. Chính sách User Data của Google Play muốn link chính sách quyền riêng tư ở cả hai chỗ: trong Play Console và ngay trong app. Dùng đúng URL đã khai trên store, cũng là `privacyUrl` trong `horus-game.json` (SDK 0.28.0: studio tự điền; bảng xin đồng ý của MAX ở vùng GDPR dẫn tới link này). Trong app, một link `https://` thường (`<a href="https://...">`) mở bằng trình duyệt của máy, game không rời trang. Crash Ramp v100s làm như vậy: Settings có dòng Privacy Policy cho mọi người chơi, cộng nút Privacy settings ở vùng GDPR.

Vòng đời: `platform.on('pause')` dừng game, tắt nhạc, lưu; `resume` chạy lại. Nút Back Android: `platform.onBack(() => closeTopPopup())` (trả `true` khi đã đóng một popup; ở menu trả `false` để app ra nền).

Màn hình: game phủ kín mọi máy; giữ chữ và nút trong vùng an toàn (`env(safe-area-inset-*)` trong CSS, sự kiện `platform.on('insets')`). Chữ dài theo ngôn ngữ phải tự co cho vừa nút.

Ngôn ngữ: chữ trong `src/i18n/<lang>.json`, không viết chữ thẳng trong code; tiếng Anh trước, rồi các ngôn ngữ trong `languages` của `horus-game.json`. Ngôn ngữ không phải chữ Latin cần font riêng nằm trong bản build.

### Quốc gia của người chơi khi không có mạng (Crash Ramp v100d, cờ nước ở vạch xuất phát)

- Dùng múi giờ của máy trước: `Intl.DateTimeFormat().resolvedOptions().timeZone`, đổi ra nước bằng `zone.tab` của tz database cùng các link.
  - Giữ các link: Chrome và Android WebView trả tên cũ của ICU như `Asia/Saigon`, `Asia/Calcutta`.
  - Bảng 541 múi giờ chỉ 9 KB.
- Múi giờ là UTC / GMT (máy test, máy ảo) thì dùng ngôn ngữ: vùng của `navigator.languages` đầu tiên (`vi-VN` ra VN), hoặc ngôn ngữ chỉ nói ở một nước (`vi` ra VN).
- Không tin vùng của ngôn ngữ hơn múi giờ: `en-US` rất hay gặp trên máy ở Canada, Anh và nhiều nước khác.
- Máy Windows đặt vùng không phải nước mình có một múi giờ cho nhiều nước (ví dụ "SE Asia" thành `Asia/Bangkok` cho Việt Nam, Thái Lan, Indonesia). Chỉ với các múi đó, ưu tiên nước của ngôn ngữ nếu nước đó cùng giờ (kiểm bằng `Intl` `formatToParts` ở múi giờ của nước đó).
- Cờ: flag-icons (MIT), để file giấy phép cạnh asset.
  - Mỗi cờ một ảnh WebP nhỏ, xếp nối nhau trong một file kèm bảng vị trí kết thúc của từng cờ; chỉ giải mã cờ của người chơi.
  - Một tấm lưới 2048 x 1536 tốn 12 MB khi giải mã, nguy hiểm với máy 2 GB.
  - Đừng chép file cờ qua thư mục chung của dự án (nó viết lại file bắt đầu giống WebP): chép bản gzip, hoặc dùng binary patch của git.
- Trong 3D:
  - Tấm vải tỉ lệ 4:3 như ảnh cờ để biểu tượng tròn (Nhật, Bangladesh) vẫn tròn.
  - Hai mặt, cả hai lấy mép trong (hoist) của ảnh ở phía cột (Crash Ramp v100e). Mặt sau vì thế thấy cờ bị lật như cờ thật trên cột, nên góc sao của cờ Mỹ và màu xanh của cờ Pháp luôn ở phía cột từ cả hai phía. Bản v100d cho cả hai mặt đọc xuôi, nên từ một phía góc sao của cờ Mỹ nằm ở đầu tự do.
  - Chỉ cờ có chữ (Ả Rập Xê Út, Iraq, Afghanistan, Iran, Brazil) đọc xuôi ở cả hai mặt; ngoài đời các cờ này may hai lớp để chữ không bao giờ bị lật.
  - Các tấm vải màu dùng chung material với cờ thì gắn map trắng 1 x 1 để cả hai lần vẽ dùng một shader program, menu không thêm program phải biên dịch.
  - Chỉ một lá cờ nước, ở chỗ người chơi nhìn lâu nhất (Crash Ramp v100q: lá cờ sau ná ở màn TAP TO START). Lá thứ hai ở chỗ khác trông như lỗi, không như trang trí; các cờ khác giữ màu của map.
  - Sóng vải trong vertex shader phải chạy từ cột ra đầu tự do: `offset = sin(time * w - distFromPole * k + phase) * amp * distFromPole`. Viết `+ distFromPole * k` thì đỉnh sóng chạy vào phía cột và người chơi thấy cờ "bay ngược" (Crash Ramp v100q). Ảnh chụp đứng yên không thấy lỗi này: tấm vải trông lạ khi chuyển động thì kiểm dấu trước.
- Đo nó: cờ nước là một A/B, không phải điều hiển nhiên. Mỗi lượt cài nhận một nhánh một lần (kit `assignAB`, ví dụ `nat_flag: { variants: ['country', 'color'], weights: [1, 1] }`), gửi nhánh thành user property (`ab_nat_flag`) ở sự kiện đầu tiên, giữ một công tắc Remote Config để kết thúc (`feat_natFlagAb` 0 = mọi người nhận nhánh thắng), và chọn nhánh trước khi dựng cảnh đầu tiên. Đọc D1 / D3 / D7 theo nhánh từ lượt cài của bản có A/B (Crash Ramp data review, `queries.sql` Q14). Tham số web để thử (`?country=xx`) vẫn phải hiện cờ ở cả hai nhánh.

**Xong khi:** mỗi nút trong Settings làm đúng việc trên trình duyệt; link Privacy Policy mở được (cả khi không phải vùng GDPR); đổi ngôn ngữ không có chữ tràn nút; nút Back đóng popup trên cùng.

## 18. Kiểm tra trước khi build

Trên trình duyệt (cỡ điện thoại, CPU chậm 4 lần):
- Chơi từ save trống tới qua Map 1: không lỗi Console, không kẹt quá 3 lượt không mua được gì.
- Rewarded: xem hết thì thưởng, đóng sớm không; không có quảng cáo thì báo, không treo.
- Mua hàng: lưu trước `finish` sau, không giao hai lần, `pending()` lúc mở game, Restore.
- Interstitial đúng luật bước 10; Remove Ads bỏ được nó.
- Tải lại trang ở mọi màn: tiến độ còn.
- `horus-game.json` khớp code (placement, SKU, khoá Remote Config, sự kiện).
- Không có Google Analytics, AdSense, Firebase JS hay SDK quảng cáo nào khác; không tải gì từ CDN.

Trên máy thật yếu, vì trình duyệt máy tính không cho thấy hết RAM, GPU và WebView cũ:
- Firebase Test Lab, kịch bản Game Loop (`platform.testLoop`): game tự chơi khoảng 10 phút, ghi fps, qua lần đổi map và một lần giả lập quảng cáo (bước 5), rồi báo kết quả. Chọn một máy 2 GB (Galaxy A10 có WebView Chrome 81) và một máy tầm thấp khác.
- Gói Blaze của Firebase cho 30 phút máy thật mỗi ngày miễn phí, quá thì tính tiền theo phút. Giữ timeout dưới 13 phút, tối đa 2 máy một ngày, và để Test Lab lưu kết quả ở bucket mặc định (bucket riêng tính tiền lưu trữ). Test Lab sẽ dừng ngày 30/9/2027.
- Máy ảo (LDPlayer, BlueStacks): bản release coi là robot nên không có quảng cáo thật. Đừng bật quảng cáo thật trên máy ảo: mạng quảng cáo tính là traffic không hợp lệ. Kiểm đường nhẹ khi quảng cáo bằng bước giả lập.

**Xong khi:** mọi dòng trên đã kiểm; `node horus-sdk/horus-build.mjs --dry-run` không còn dòng `chú ý:`.

## 19. Build ra app

```
node horus-sdk/horus-build.mjs --dry-run       # kiểm gói gửi đi
node horus-sdk/horus-build.mjs                 # APK cài thử
node horus-sdk/horus-build.mjs --aab           # khi Horus đã cài đặt game (appId)
```

`--play` và `--ios` chỉ khi người dùng yêu cầu. Mỗi bản gửi store tăng `GAME_BUILD`.

Cập nhật nóng (bản web mới tới người chơi không qua store, `packages/webgame/HOT.md`) mặc định tắt; Horus bật cho từng game. Chỉ cho JS, ảnh, âm thanh, dữ liệu; code native, SDK, icon vẫn cần bản store. Bản nóng đặt `--id` trùng build tag của game. Người dùng thích bấm thì mở trang build: `node horus-sdk/horus-build.mjs ui` (Windows: bấm đúp `horus-sdk\HorusBuild.cmd`). Lỗi thì đọc dòng lý do và log; gửi mã job cho Horus nếu cần.

Ảnh UI nướng sẵn hay kèm theo app (thumbnail, icon có alpha): WebP chất lượng khoảng 0,9 với alpha lossless, không dùng PNG. Mã hoá bằng chính trình duyệt dùng để nướng (`OffscreenCanvas.convertToBlob({ type: 'image/webp', quality })`) và bỏ chunk ICCP (WebP không gắn profile là sRGB, điểm ảnh giải ra y hệt); chỉ giữ PNG dự phòng khi trình duyệt không mã hoá được. WebP chạy được ở mọi nơi kit ship (Android WebView, WKWebView iOS 14+, Safari 14+). Crash Ramp v100t: 36 thumbnail xe từ 1,64 MB PNG xuống khoảng 0,36 MB. Đo phần một bản thêm vào bằng so từng file trong hai AAB của job (cỡ nén của `base/` cho một ABI), không tin con số "so với bản trước" của Play (lệch 4 MB với nội dung AAB của Crash Ramp 0.1.2).

**Xong khi:** có APK trong `build-online/`, cài vào máy Android mở được, chơi một lượt có quảng cáo thử.

## 20. Để được store feature (App Store, Google Play)

Không store nào có checklist bắt buộc: biên tập chọn theo chất lượng, trải nghiệm, trợ năng, ngôn ngữ, trang store và nội dung theo mùa. Làm từ đầu thì rẻ hơn làm sau (Crash Ramp, 24/10/2026).

Trong game:
- **Trợ năng.** Settings có "Reduce motion" (theo `prefers-reduced-motion` của máy cho tới khi người chơi tự bật tắt: rung camera, chớp màn hình, hiệu ứng màu giảm còn khoảng 30%, animation lặp của menu chạy một lần) và "Larger text" (chữ nhỏ dưới 18px phóng 1,2-1,3 lần; mặc định bật khi `platform.info.fontScale` từ 1,3). Mọi nút có chữ hoặc `aria-label`, công tắc có `role="switch"` + `aria-checked`. Vùng chạm từ 48px (thêm vùng chạm vô hình bằng `::before` nếu nút nhỏ hơn). Chữ phụ tương phản từ 4,5:1 với nền.
- **Game Center / Play Games** (`platform.games`, module `games`): bảng xếp hạng (quãng đường xa nhất mỗi map, mùa cao nhất) và ít nhất 10 thành tích, ít nhất 4 cái đạt được trong giờ chơi đầu, tối đa 1 cái trong 5 phút đầu. Đọc từ save, gửi lại tất cả khi có sự kiện `'games'` `{ signedIn: true }` (store giữ điểm cao nhất, bỏ qua mở khoá lần hai). Nút "Leaderboards / Achievements" trong Settings khi `platform.games.signedIn`. Khoá bảng và thành tích là hợp đồng: không đổi nghĩa khi đã lên store.
- **Sự kiện theo mùa** có thật trong game (không phải quà hằng ngày hay giảm giá): đó là nội dung cho In-App Events (iOS) và Promotional content (Play).
- **Kiếm tiền không làm phiền:** không mời mua ngay khi vào game, không chèn quảng cáo giữa màn, offer đúng lúc (bước 13).
- **Ổn định:** crash dưới 1,09%, ANR dưới 0,47% (Android vitals, 28 ngày); dưới 30 fps là mất điểm.

Ngoài game (Horus làm với tài khoản store):
- Game Center: bật cho app trong App Store Connect, tạo bảng và thành tích cùng khoá (ảnh thành tích 1024x1024), gửi duyệt cùng bản app. Play Games: tạo trong Play Console, chép mã project và id từng bảng, thành tích (dạng `CgkI...`, icon 512x512) vào `sdk.games` của `webgame.config.json`; publish ít nhất 2 giờ trước khi game lên.
- Đề cử Apple: App Store Connect > Featuring > Nominations, ít nhất 3 tuần trước ngày muốn lên, tốt nhất 3 tháng.
- In-App Event: tên 30 ký tự, mô tả 50 và 120; ảnh 16:9 1920x1080 và 9:16 1080x1920, không chữ, không logo; 15 phút tới 31 ngày. App Store Connect không cho nộp event thiếu "Event deep link": bản app trên store phải có `urlScheme` (`horus-game.json`, SDK 0.30.0) và game mở thẳng màn sự kiện với `<urlScheme>://event` (`platform.link.opened` lúc mở, sự kiện `'link'` lúc đang chạy; README mục 11). Promotional content Play: ảnh 1920x1080 không chữ, tagline 80, mô tả 500, tối đa 4 tuần, gửi trước ít nhất 4 ngày.
- Trang store: video gameplay 15-30 giây (iOS) và YouTube (Play), ảnh có chữ bản địa cho thị trường lớn, nhãn trợ năng App Store chỉ khai cái game đạt thật (Larger Text cần chữ 200%, Reduced Motion không khai được nếu quảng cáo video không giảm được chuyển động).

**Xong khi:** Settings có Reduce motion, Larger text và (trong app) Leaderboards / Achievements; mọi nút từ 48px; README của game ghi khoá bảng và thành tích; có ít nhất một sự kiện mùa chạy được trong game.

## 21. Crash và ANR sau khi ra mắt

Crash và ANR là lỗi nặng nhất: người chơi gặp một lần là hay gỡ game, và Google Play hạ hạng game vượt ngưỡng (crash 1,09%, ANR 0,47% người dùng trong 28 ngày). Đọc Crashlytics mỗi ngày trong tuần đầu của mỗi bản, rồi mỗi tuần.

**App tự bắt gì.** Android: crash Java, crash native (NDK, có symbol), ANR (Android 11 trở lên), WebView renderer chết. iOS: crash (có dSYM), treo máy, quá CPU và bị hệ thống giết (MetricKit), tiến trình web bị tắt. Lỗi JavaScript thì chỉ lên khi game gọi `platform.crash` (bước 4). Mỗi báo lỗi có sẵn phiên bản app, module, kích thước save và mọi user property (kể cả `webview`); thêm chỗ người chơi đang đứng bằng `platform.crashKeys({ map, screen })`.

**Đọc cho đúng.**
- Đếm người chơi, không đếm sự kiện: ở Crash Ramp, một máy Vivo còn ở bản cũ gửi 13 báo cáo "renderer gone".
- Xem bản nào. Người chơi không cập nhật vẫn gửi lỗi của bản cũ; lỗi đã sửa thì chỉ xét trên bản mới.
- Bỏ robot: máy báo cáo trước khi ra mắt của Google Play, Firebase Test Lab, máy ảo. ANR `nativePollOnce` trên máy test của Google không phải người chơi.
- `renderer_gone` (sự kiện analytics, `state` `fg`, `ad` hoặc `bg`): `bg` là hệ thống lấy lại RAM khi app ở nền, không phải crash, và không lên Crashlytics. Chỉ `fg` (đang trên màn hình) và `ad` (dưới quảng cáo) là lỗi người chơi thấy.
- Xem sự kiện analytics ngay trước lỗi: Crash Ramp tìm ra renderer chết dưới quảng cáo thưởng nhờ thấy `rv_start` rồi `boot` mà không có `rv_done`, và tìm ra chạm hai lần nhờ hai `rv_start` cách nhau 30-70 ms. Nhưng kiểm trước xem có phải mọi sự kiện của máy đó đều lặp không: một iPhone XR gửi mọi sự kiện hai lần cách nhau 0,23 giây, đó là analytics lặp, không phải người chơi chạm hai lần.
- Đọc qua BigQuery (Firebase export): bảng hằng ngày và bảng `_REALTIME` có cột khác nhau, truy vấn riêng; tên luồng là `threads[].thread_name`. Truy vấn hẹp (vài ngày, vài cột) để rẻ.

**Lỗi đã gặp và cách sửa** (Crash Ramp, 10-11/2026):

| Thấy gì | Vì sao | Sửa |
| --- | --- | --- |
| Crash nặng SIGTRAP trong `libwebviewchromium` `draw_gl`, dưới video quảng cáo | Chạm hai, ba lần vào nút quảng cáo; lần sau trả "không có quảng cáo", game vẽ lại cảnh 3D và bật nhạc ngay dưới video | Mỗi lúc một quảng cáo: `platform.ads.busy()`, gặp `busy` thì không đổi gì (bước 8, SDK 0.26.1) |
| Xem hết quảng cáo thưởng mà không được thưởng, game mở lại ở menu | Máy ít RAM tắt trang web dưới quảng cáo | Nhẹ khi quảng cáo che game (bước 5), trả thưởng bằng `platform.ads.lost` (bước 8) |
| ANR trong `RenderThread` `draw_gl` lúc mở game lần đầu 53 giây | Mở game quá lâu trên máy yếu | Mở game nhanh (bước 5) |
| Đứng mãi ở màn tải Map 2 trên máy 2 GB | Code nạp map chờ khung hình không giới hạn khi RAM gần hết | Luật nạp map và watchdog (bước 5) |
| Lỗi JS `tick` rồi kẹt màn tải, khi app bị chuyển ra nền ngay lúc mở | Timer cần WebGL chạy trước khi có WebGL | Không đặt timer cần WebGL trước khi có (bước 5) |
| Trang tải lại hay kẹt trên WebView 80-87 | API mới hơn WebView (`animate` keyframe thiếu, `getAnimations`, `replaceAll`, `:where()`) | Build cho Chrome 80, `@horus/webgame/compat`, tự tránh phần polyfill không cứu được (bước 5) |
| iPhone mất nhạc, lỗi JS "Decoding failed" | Nhạc `.ogg` | Dùng `.mp3` (bước 5) |
| Một iPad không tạo được WebGL | Có thể do Lockdown Mode (chưa chắc) | Gửi `boot_fail` `stage: 'init'` (bước 16), hiện một dòng báo thay vì màn đen |
| SIGSEGV trong WebView trên máy chỉ còn 151 MB RAM trống | Lỗi của WebView, không do game | Theo dõi, không sửa gì |

**Mỗi lỗi mới, làm theo thứ tự:**
1. Bản nào, bao nhiêu người chơi thật, máy và WebView nào.
2. Stack, key, và sự kiện analytics trước lỗi của vài người chơi đó.
3. Làm lại được lỗi: điện thoại cắm USB (`adb`), máy ảo Android, Firebase Test Lab trong quota miễn phí, Chrome bản cũ cho lỗi WebView cũ.
4. Sửa, kèm một test hỏng trên code cũ và qua trên code mới; nếu cần đo thêm thì thêm một sự kiện analytics cho đúng chỗ đó (Crash Ramp thêm `ad_dup`).
5. Ra bản mới. Chỉ nói "đã hết lỗi" khi người chơi đã lên bản đó và Crashlytics cùng sự kiện mới không còn thấy lỗi.

**Xong khi:** game gọi `platform.crash` cho `error` và `unhandledrejection`, có `platform.crashKeys` ở mỗi màn; một lỗi thử (`throw` trong Settings bản test) hiện trên Crashlytics kèm map và màn; có một người được giao đọc Crashlytics mỗi ngày trong tuần đầu.
