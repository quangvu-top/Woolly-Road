# AGENTS.md: game three.js (HTML5) dùng Horus SDK

Dành cho AI agent (Claude Code, Cursor, Codex, Copilot...) làm việc trong repo một game phát hành cùng Horus. Người đọc cũng dùng được như một checklist. Hướng dẫn đầy đủ cho người: `README.md` cạnh file này. API và chú thích từng hàm: `horus-sdk.d.ts`.

Đặt file này ở gốc repo game, hoặc thêm vào `AGENTS.md` / `CLAUDE.md` sẵn có một dòng: "Đọc horus-sdk/AGENTS.md trước khi sửa quảng cáo, mua hàng, analytics, lưu game, hiệu năng hay build app."

Game làm bằng Godot thì dùng `horus-sdk/godot/AGENTS.md` thay cho file này.

## Bối cảnh

- Game là web (HTML5). Horus bọc nó thành app Android/iOS. Repo này không có và không cần code Android/iOS, Gradle, Xcode hay khoá ký.
- `horus-sdk.js` (global `HorusSDK`) hoặc `horus-sdk.mjs` là cầu nối duy nhất tới quảng cáo, mua hàng, analytics, Remote Config, cloud save. Trên trình duyệt, SDK giả lập quảng cáo và mua hàng. Trong app, nó dùng thật. Không cần nhánh code riêng cho hai nơi.
- `horus-build.mjs` gửi bản build web cho Horus và tải về APK/AAB (Build online). Đó là cách duy nhất ra app.

## Quy tắc khi sửa code

1. Gọi `await HorusSDK.start({ skus: [...] })` một lần trước khung hình đầu, rồi `platform.ready()` khi màn đầu đã vẽ.
2. Rewarded: chỉ thưởng khi `(await platform.ads.rewarded('<placement>')).ok === true`. Placement viết chữ thường, không dấu, và có trong `horus-game.json` (`ads.rewarded` / `ads.inter`).
3. Mua hàng: cộng hàng vào bản lưu và lưu ngay (`store.save`), **sau đó** mới `platform.iap.finish(...)`. Mỗi `token` giao một lần (ghi vào `buys`). Lúc mở game, giao hết `await platform.iap.pending()`. Món mua một lần dùng `consumable: false` và có nút Restore khi `platform.iap.restorable`. `status: 'invalid'` là đơn giả: không thưởng.
4. Lưu game qua `HorusSDK.save.createSaveStore` với `mirror: (json) => platform.save.mirror(json)`, hoặc gọi `platform.save.mirror` mỗi lần game tự lưu. Chỉ dùng localStorage thì người chơi mất tiến độ khi cài lại.
5. `platform.on('pause')` thì dừng game và tắt nhạc (quảng cáo đang chạy hoặc app ra nền); `resume` thì chạy lại.
6. Không thêm SDK quảng cáo, analytics, thanh toán hay tracking khác (Google Analytics, gtag, AdSense, Firebase JS, Stripe...). Horus đã gắn trong app; thêm vào sẽ trùng số liệu hoặc bị store từ chối.
7. Không tải gì từ CDN hay Internet lúc chạy: font, thư viện, ảnh đều nằm trong bản build, đường dẫn tương đối. App phải mở được khi không có mạng.
8. Tên sự kiện analytics và tham số: chữ thường, `snake_case`, giá trị phẳng (số, chuỗi). Ghi sự kiện mới vào `events` của `horus-game.json`.
9. Remote Config: `platform.rc.values.<khoá>` luôn là chuỗi, luôn có giá trị mặc định trong code. Khoá mới ghi vào `remoteConfig` của `horus-game.json`.
10. Không sửa, format lại hay bọc lại `horus-sdk.js` / `.mjs` / `horus-build.mjs`. Bản mới lấy từ Horus và thay nguyên file.
11. Trước khi tự viết luật interstitial, bậc thiếu xu, quà ngày, nhiệm vụ, lịch thông báo, đường giá, vỏ renderer three.js hay hiệu ứng hạt: dùng `monetize`, `liveops`, `economy`, `app`, `fx`, `perf` của SDK (README mục 13, kiểu trong `horus-sdk.d.ts`). three.js truyền vào (`THREE`), không lấy từ SDK.
12. Settings luôn có link **Privacy Policy** (link `https://` thường, mở trình duyệt) cho mọi người chơi, ở mọi vùng; thêm nút "Privacy settings" gọi `platform.ads.privacy()` khi `platform.ads.hasPrivacy` (chỉ vùng GDPR). Google Play muốn link chính sách cả trong Play Console lẫn trong app. Consent do app lo (GAME-GUIDE mục 17: Adjust mang consent DMA của Google, Facebook không chờ consent theo lựa chọn của studio); không gửi dữ liệu người chơi cho bên thứ ba từ JS.
13. Cập nhật nóng (README mục 11): không gọi `platform.hot.apply()` giữa lúc chơi (trang tải lại), chỉ ở menu. Thay đổi cần SDK, quyền hay cấu hình app mới thì nói với người dùng là phải ra bản store, không chỉ cập nhật nóng.
14. Deep link (README mục 11, SDK 0.30.0): In-App Event của App Store cần "Event deep link". Đặt `urlScheme` trong `horus-game.json` (chữ thường, ví dụ `mygame`), rồi mở màn sự kiện từ `platform.link.opened` lúc khởi động và `platform.on('link', ...)` lúc đang chạy (`path` `event` cho `mygame://event`). Không tự đọc `location` hay `window.open` để làm deep link.

## Hiệu năng và crash

Luật rút ra từ Crash Ramp trên máy thật; chi tiết và số đo ở mục 5, 8 và 21 của `GAME-GUIDE.md`.

1. Build JS cho Chrome 80 và nạp Horus SDK trước code game: file SDK tự vá vài hàm WebView cũ thiếu (`.at()`, `replaceChildren`, `roundRect`, `animate()`, `getAnimations`). Không dùng API mới hơn Chrome 80 mà polyfill không cứu được: `String.prototype.replaceAll`, CSS `:where()`, `inset`. Một `replaceAll` trong bản thử làm Galaxy A10 (WebView 81) không vẽ gì.
2. Không bao giờ hạ độ phân giải, tắt bóng, tắt bloom hay đổi hình để có fps mà người dùng chưa chọn. Việc "không đổi hình" phải so từng điểm ảnh: cùng một khung vẽ hai cách, lệch tối đa 1/255.
3. Độ nét tự động: mở ở độ nét của máy, chỉ hạ khi 15 giây liền đang chơi đều 30 khung/giây trở xuống, từng bậc một, bậc thấp hơn phải nhanh hơn thật mới giữ (mục 5).
4. Không kết luận fps từ Chrome headless, SwiftShader hay máy ảo: chỉ máy thật (Firebase Test Lab trong quota miễn phí, điện thoại cắm USB). So trong cùng một lần chạy, xen kẽ hai bản.
5. Không gửi lệnh vẽ rỗng (bộ hạt chưa có hạt thì `visible = false`); vật liệu cộng sáng hai mặt đặt `forceSinglePass`; không bật tắt bóng hay loại vật liệu giữa lượt chơi (máy yếu đứng vài giây để dịch shader).
6. Vẽ tối đa 60 khung/giây (`platform.device.setFrameRate(60)`); máy ấm (`platform.device.thermal`) thì giới hạn 30 khung/giây, giữ nguyên độ nét.
7. Mỗi lúc một quảng cáo: hàm bấm nút quảng cáo kiểm `platform.ads.busy()` trước mọi việc, và gặp `reason: 'busy'` thì không đổi gì. Thiếu điều này, chạm hai lần làm WebView crash dưới video.
8. Trước quảng cáo nhả bộ đệm vẽ (`adLightOn` ở mục 5 của hướng dẫn), sau quảng cáo trả đúng pixel ratio và kích thước cũ; trả thưởng của `platform.ads.lost` ngay sau khi đọc save, rồi `lostDone()`. Không bao giờ cho gem ở chỗ vốn không cho gem.
9. Nạp map: giải phóng map cũ trước, mọi lần chờ khung hình tối đa 100 ms, có watchdog 30 giây (không tính lúc app ở nền), không đặt timer cần WebGL trước khi có WebGL.
10. Nhạc `.mp3`, không `.ogg`; `pause` thì nhả nhạc nền khỏi bộ nhớ.
10b. Quảng cáo thưởng có thể kết thúc bằng Android tắt cả app (máy 2-4 GB, khoảng 1 trên 10): ghi nhớ phần thưởng vào save trước quảng cáo, lần mở sau trả một lần khi `platform.device.exits` có lần hệ thống tắt app 5 giây - 10 phút sau lúc quảng cáo bắt đầu; không bao giờ trả gem kiểu này (mục 8). Máy không có `KHR_parallel_shader_compile`: mỗi khung dịch một shader program, không dồn vào một khung (mục 5, "Mở game nhanh").
11. Bắt lỗi: `platform.crash` cho `error` và `unhandledrejection`, `platform.crashKeys({ map, screen })` khi đổi màn. Sửa crash theo mục 21: đếm người chơi thật và bản, tìm bằng chứng, sửa kèm test; chỉ báo "đã hết lỗi" khi người chơi đã lên bản mới và Crashlytics không còn thấy.

## Làm game mới

Người dùng nhờ làm một game mới (hoặc "game như Crash Ramp"): đọc `horus-sdk/GAME-GUIDE.md` từ đầu tới cuối trước khi viết code, rồi làm lần lượt từ bước 0.

1. Bước 0: viết `docs/design.md` (vòng chơi, tiền theo gì, nâng cấp, map) và hỏi người dùng những gì chưa rõ. Chưa được đồng ý thì không dựng cảnh 3D.
2. Mỗi bước: làm xong, kiểm đủ mục **Xong khi** của bước đó trên trình duyệt, báo người dùng một dòng, rồi mới sang bước sau.
3. Con số (giá, tiền, luật quảng cáo, offer, thông báo) để trong `src/config.js`, ghi đè được bằng Remote Config (`monetize.applyConfig`). Bắt đầu từ số của Crash Ramp trong hướng dẫn; đổi số kinh tế thì chạy lại mô phỏng (`economy.simulateEconomy`) và cho người dùng xem bảng.
4. Mỗi nút mời xem quảng cáo gửi `rv_offer` khi hiện ra, `rv_start` / `rv_done` khi xem; mọi lần nhận hay tiêu tiền gọi `platform.an.earn` / `spend`.
5. Không đổi luật đã chốt (kinh tế, quảng cáo, offer) mà không hỏi người dùng; ghi mỗi quyết định vào `docs/design.md` kèm ngày.
6. Hiệu năng: thử ở chế độ thiết bị của Chrome với CPU chậm 4 lần sau mỗi bước có đồ hoạ mới (ngân sách ở bước 5 của hướng dẫn), và trên một máy Android yếu thật trước khi báo xong game.

## Build và gửi

```
npm run build                                  # build web của game (ra thư mục trong "web" của horus-game.json)
node horus-sdk/horus-build.mjs --dry-run       # kiểm tra gói gửi đi, không gửi
node horus-sdk/horus-build.mjs                 # APK cài thử, về build-online/
node horus-sdk/horus-build.mjs --aab           # AAB tải về (chỉ khi Horus đã cài đặt game)
node horus-sdk/horus-build.mjs --play          # AAB lên Google Play internal (chỉ khi người dùng yêu cầu)
node horus-sdk/horus-build.mjs --ios           # iOS lên TestFlight (chỉ khi người dùng yêu cầu)
node horus-sdk/horus-build.mjs ui              # trang build cho người dùng (họ bấm, không phải agent)
```

- Người dùng muốn một trang để build (bấm build, xem tiến độ, tải app): mở `horus-sdk\HorusBuild.cmd` (Windows) hoặc `node horus-sdk/horus-build.mjs ui`. Agent không tự làm trang, server hay script build riêng thay cho chúng: trang có sẵn đúng luật của Horus (mã build, store, cập nhật SDK). API trong `BUILD-API.md` chỉ dùng cho việc trang không làm (bot báo tin, CI).
- `--play` và `--ios` đưa app lên store: agent chỉ chạy khi người dùng yêu cầu rõ trong lượt đó. Không có production; không thử track khác ngoài `internal` nếu Horus chưa cho.
- Mã build: người dùng chạy `node horus-sdk/horus-build.mjs --key <mã>` một lần, hoặc đặt `HORUS_BUILD_KEY`. Agent không tự tạo, không in, không ghi mã vào repo, log hay commit. Thiếu mã thì dừng và nhắc người dùng xin Horus.
- SDK tự cập nhật khi gửi build (dòng "Đã cập nhật Horus SDK ..."): đọc CHANGELOG.md mới, sửa game nếu API đổi, build lại bản web rồi gửi lại. Dòng "Có Horus SDK ... (đổi lớn)": báo người dùng, không tự chạy `update --major`. Không sửa file trong `horus-sdk/` và không commit `horus-sdk/.old/`.
- Chạy `--dry-run` trước và xử lý mọi dòng `chú ý:` (thiếu SDK trong bản build, tải từ CDN, thiếu icon).
- Build lâu vài phút: dùng `--no-wait` rồi `--job <mã>` nếu công cụ của agent có giới hạn thời gian cho một lệnh.
- `build-online/` là file tải về: để trong `.gitignore`.
- Lỗi "Horus has not set this app up for release builds" khi `--aab`: Horus chưa duyệt team cho `appId` này. Báo người dùng; APK thử vẫn build được.
- Id của app (ad unit MAX, Adjust, Facebook, licence key, file Firebase) do studio tự điền trong `horus-game.json` (README mục 12, "Id của app"): id riêng từng nền tảng ở `android.sdk` / `ios.sdk`, iOS không dùng id của Android; `google-services.json` phải có app Android trùng `appId`. Không tự bịa id: thiếu thì hỏi người dùng.

## Kiểm tra trước khi báo xong

- Mở game trên trình duyệt (cỡ màn điện thoại): không lỗi Console; nút xem quảng cáo, mua hàng chạy với quảng cáo/mua giả lập.
- Mua hàng rồi tải lại trang: hàng vẫn còn, không giao hai lần.
- `horus-game.json` khớp code: mọi placement, SKU (giá USD, consumable), khoá Remote Config, sự kiện đều có.
- Id của app trong `horus-game.json` đủ cho bản sắp gửi (`node horus-build.mjs --dry-run` không báo lỗi id hay file Firebase).
- `node horus-sdk/horus-build.mjs --dry-run` không còn `chú ý:`.
- Sau một quảng cáo giả: không nhạc, không vẽ dưới quảng cáo, `renderer.domElement` đúng kích thước cũ; chạm ba lần liền vào nút quảng cáo chỉ mở một quảng cáo.
- Trang chạy trên Chrome 81 (hoặc Test Lab Galaxy A10) không lỗi.
- Settings có link Privacy Policy mở được, không phụ thuộc `platform.ads.hasPrivacy`.

## Ví dụ

`example/` trong gói SDK là một game đủ: `index.html` (start, rewarded, mua hàng, lưu, pending), `horus-game.json`, `horus-sdk.js`. Build thử: `node horus-build.mjs example`.

## Gọi máy chủ build

Cần trạng thái job, vị trí trong hàng chờ (`queuePosition`, `jobsAhead`), dừng job hay tải app từ code hay script: đọc `horus-sdk/BUILD-API.md`, không đoán API. Mã build lấy từ biến `HORUS_BUILD_KEY` hay file mã đã lưu, không bao giờ ghi vào repo.
