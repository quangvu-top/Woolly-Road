# CHANGELOG của Horus SDK (@horus/sdk)

Định dạng theo [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), phiên bản theo semver.

## [Unreleased]

## [0.30.2] - 2026-11-05

### Đổi

- `AGENTS.md`, `GODOT-AGENTS.md`: người dùng muốn trang build thì mở HorusBuild.cmd / `horus-build.mjs ui`; agent không tự làm trang build riêng. `BUILD-API.md` mở đầu bằng trang build có sẵn, API chỉ cho bot báo tin, CI.

## [0.30.1] - 2026-11-05

### Đổi

- `@horus/webgame` ^0.62.0: tin báo build lên store vào nhóm của từng game (trang admin build), không vào nhóm của game khác. SDK không đổi API.

## [0.30.0] - 2026-11-05

### Thêm

- Deep link: `urlScheme` trong `horus-game.json` (ví dụ `mygame`) cho app một scheme riêng, `mygame://event` mở game; App Store Connect cần nó làm "Event deep link" khi nộp In-App Event. Trong game: `platform.link.opened` (`{ url, path, query, openedAt }`, app mở bằng link) và sự kiện `'link'` (link mở lúc game đang chạy); app tự ghi `link_open { path }`. Lệnh gửi build kiểm scheme theo đúng luật của máy build (chữ thường, 2-32 ký tự, không `http` / `https` / `file` / `fb...`) và dừng khi sai. Cần máy build `@horus/webgame` 0.61.0. Tài liệu: `dev/README.md` mục 11 và 12, `AGENTS.md` quy tắc 14, `GAME-GUIDE.md` mục 20, `dev/horus-game.json` mẫu.
- `BUILD-API.md` trong gói SDK (và trang "API máy chủ build" trên trang tài liệu): các API của máy chủ build (gửi, theo dõi, dừng, tải app, bản SDK mới nhất) để studio làm công cụ riêng hay cho AI agent đọc. `AGENTS.md`, `godot/AGENTS.md` chỉ agent tới file này.
- `GET /jobs/<id>` có `queuePosition` (1 = job kế tiếp) và `jobsAhead` (số job chờ gửi trước, mọi team, cả Android và iOS) khi job đang xếp hàng, `null` khi không. `horus-build.mjs` và trang HorusBuild hiện "thứ N trong hàng, M job đứng trước" và báo lại khi vị trí đổi. Cần máy chủ build từ `@horus/webgame` 0.61.0.

## [0.29.1] - 2026-11-05

### Đổi

- Tài liệu (bài học Crash Ramp v101c): `GAME-GUIDE.md` mục 8 thêm "Quảng cáo thưởng xong thì Android tắt luôn cả app" (ghi nhớ thưởng vào save, trả khi `platform.device.exits` có lần hệ thống tắt app, không bao giờ trả gem kiểu này); mục 5 "Nhẹ khi quảng cáo che game" nhả thêm bản GPU của hình khối / texture trên máy 4 GB trở xuống; "Mở game nhanh": không có `KHR_parallel_shader_compile` thì mỗi khung dịch một program (8,3 giây một khung trên máy 2 GB, ANR PowerVR). `AGENTS.md` và `GODOT-AGENTS.md` thêm luật tương ứng.

## [0.29.0] - 2026-11-05

### Thêm

- `horus-game.json`: studio điền nốt các lựa chọn của module (MAX `consentFlow`, `showTermsInGdpr`, `debugUserGeography`; Adjust `environment`, `logLevel`; Facebook `autoLogAppEvents`, `advertiserId`, `purchases`, `adRevenue`; Crashlytics `ndk`; Play Games `suppressProfileCreation`; Play Integrity `onTamper`; bật / tắt `review`, `update`) và cài đặt app iOS (`ios.attText`, `ios.devices`, `ios.languages`). Horus chỉ còn giữ khoá ký, tài khoản store, mạng quảng cáo và máy chủ. Cần máy build `@horus/webgame` 0.60.0. Tài liệu: `dev/README.md` mục 12 ("Id của app").

### Sửa

- (review) Lựa chọn studio điền: `horus-build.mjs` cảnh báo trước khi gửi giá trị máy build sẽ bỏ qua (không đúng kiểu, ngoài danh sách, `attText` sai, `devices`, `languages`); lựa chọn của MAX (`consentFlow`...) không còn tính là có MAX khi cảnh báo thiếu `privacyUrl`. Danh sách giống hệt máy build: `consentFlow` chỉ `true`, Adjust `environment` chỉ `production`, `logLevel` không có `verbose` / `debug`, `onTamper` do Horus đặt.

- `privacyUrl` / `termsUrl`: `horus-build.mjs` và trang HorusBuild dùng đúng luật của máy build (chữ ASCII, không dấu cách, dấu nháy, `<` `>` hay `\`); trước đây lệnh gửi build cho qua link có dấu nháy hay chữ có dấu mà máy build bỏ đi không báo. Trang HorusBuild nhận link dài tới 498 ký tự (trước là 190). Giá trị không phải chữ báo lỗi, không phải "chưa có".

## [0.28.0] - 2026-11-05

### Thêm

- `horus-game.json` có `privacyUrl` và `termsUrl` (link `https://`): studio tự điền trang chính sách quyền riêng tư của game. Game có quảng cáo MAX cần `privacyUrl` (bảng xin đồng ý GDPR của MAX dẫn tới đó; thiếu thì máy build từ chối bản có quảng cáo, lỗi `privacyUrl is empty`). Lệnh gửi build báo khi thiếu và dừng khi link không phải `https://`. Trang build (`horus-build.mjs ui`, HorusBuild.cmd) có ô `privacyUrl`. Cần máy build `@horus/webgame` 0.59.0. Tài liệu: `dev/README.md` mục 12 (bảng `horus-game.json`, "Id của app"), `GAME-GUIDE.md` (link Privacy Policy), `dev/horus-game.json` mẫu.

## [0.27.3] - 2026-11-04

### Đổi

- Theo `@horus/webgame` 0.58.0 và `@horus/cloudsave` 1.13.0 (máy build tự kiểm tra cloud save sau khi cập nhật, tự quay lại bản cũ khi hỏng). API của SDK không đổi.

## [0.27.2] - 2026-11-04

### Đổi

- `dev/README.md` mục 8: Horus cập nhật server cloud save của các game lên bản mới trên trang admin build (nút "Cập nhật tất cả cloud save"), game không phải build lại. Chỉ tài liệu.

## [0.27.1] - 2026-11-04

### Doc

- Doc `README.md` mục 8: server cloud save của từng game do Horus tạo trên trang admin build (một nút), studio không điền gì.

## [0.27.0] - 2026-11-04

### Thêm

- Studio tự điền id của app trong `horus-game.json`: `sdk`, `android.sdk`, `ios.sdk` (ad unit MAX, Adjust, Facebook, licence key Play...) và `firebase` (hai file Firebase, mặc định `google-services.json` / `GoogleService-Info.plist` ở gốc game). Horus chỉ tích hợp SDK và build. `horus-build.mjs` gửi kèm file Firebase và kiểm trước khi gửi (`checkStudioIds`): ad unit 16 ký tự hex, rewarded khác interstitial, iOS không dùng ad unit của Android, file Firebase đúng `appId`, id riêng của app không đặt nhầm ở `sdk`. Cần máy build từ webgame 0.55.0.
- Doc: `README.md` mục 12 "Id của app" (bảng khoá từng module), mục 1, 3 (nhiều ad unit), 6 (Remote Config), thông báo push; `AGENTS.md`, `GODOT.md`, `GODOT-AGENTS.md`; mẫu `horus-game.json` có sẵn các khối id để điền.


### Doc

- `GAME-GUIDE.md` mục 5: hủy Web Animation không có `fill` khi xong (`onfinish` gọi `cancel()`); còn gắn thì CSS animation của phần tử không chạy trên compositor (Crash Ramp v101b).

## [0.26.10] - 2026-11-04

### Thêm

- `GAME-GUIDE.md` mục 5: game three.js có đường vẽ thẳng ra màn và đường HDR: `ShaderMaterial` tự viết kết thúc bằng `#include <tonemapping_fragment>` + `#include <colorspace_fragment>`; dịch shader trước với target giống đầu ra thật (Crash Ramp v100x).
- `GAME-GUIDE.md` mục 5: số đo trên máy rất yếu (OPPO A15, PowerVR GE8320): Crash Ramp 2x 10 fps đến 1x 20 fps, JS 21 ms mỗi khung, HUD DOM 10-12 ms; khung 1x chia theo phần (mặt đất 13 ms, cây cỏ 13, trời 5, xe 5, trang 20); cấu hình máy yếu (bỏ bóng, bỏ HDR, nửa cây cỏ) 22,9 fps, ẩn thêm HUD 32,1; bản v100v có cờ máy rất yếu 26,4 fps, ẩn HUD 39,2; v100w ghi số HUD 3 khung một lần: 28,2 fps (HUD từ 14 còn 10-11 ms); v100x: khung đầu lượt 119-135 ms thay vì 175-185 ms, không biên dịch shader trong lượt; chia phần HUD: nhịp gợi ý nút tên lửa (animate `filter: drop-shadow`) tốn 10-14 ms, các phần khác khoảng 0, gộp một lớp chậm hơn; luật mới: phần tử HUD có lớp ghép riêng không mang filter, kể cả filter tĩnh (v100y: filter tĩnh + scale vẫn tốn 10 ms, bỏ filter thì hết), glow vẽ bằng box-shadow tĩnh hoặc radial-gradient, animation chỉ dùng transform và opacity (v100z làm vậy: 42,9 ms thay vì 56,3 ms khi gợi ý bật); một game Unity thủ thành 58 fps cùng máy; đo fps app bất kỳ bằng `dumpsys SurfaceFlinger --latency`.

## [0.26.9] - 2026-11-03

### Doc

- `GAME-GUIDE.md` mục 17: "Số liệu UA sau consent": tổng lượt cài và doanh thu không lệch; chỉ camp Google ở EEA lệch (người không đồng ý hiện là Organic trên Adjust, Google ước lượng phần thiếu nhờ cờ DMA); cách đọc camp, tăng tỷ lệ đồng ý qua form AdMob, không bao giờ gửi `ad_user_data=1` cho người từ chối. Cùng ý trong `GODOT.md` mục 6.
- `GAME-GUIDE.md` mục 17: hộp CONTINUE của MAX ngoài GDPR cũng giữ lượt cài Adjust tới khi bấm (đúng doc MAX và Adjust; lựa chọn của studio 3/11/2026); so lượt cài Adjust với Play sau bản phát hành.
- `GAME-GUIDE.md` mục 5, "Game online": đòn đánh của chính mình thấy nhanh (Ashlar): độ trễ đến từ đâu (RTT, đồng hồ vẽ trễ, server chờ input, nhịp gửi) và các cách bớt giữ nguyên luật (đọc socket mỗi khung, đòn của mình theo snapshot, đạn vẽ ngay khung bắn 712 xuống 340 ms, đi tới đoán trước 529 xuống 145 ms, dự phòng input 0-1 tick, một tick châm chước cho cú vung).
- `GAME-GUIDE.md` mục 5, "Bớt việc CPU": gộp sẵn vật nhỏ nhiều mảnh đứng yên (Crash Ramp v100u bệ tên lửa 17 xuống 6 lệnh vẽ).
- `GAME-GUIDE.md` mục 19: ảnh UI nướng sẵn dùng WebP chất lượng 0,9 + alpha lossless, bỏ ICCP, đo bằng so từng file AAB (Crash Ramp v100t 36 thumbnail 1,64 xuống 0,36 MB).
- `GAME-GUIDE.md` mục 5: số đo máy rất yếu PowerVR GE8320 (OPPO A15) từ máy build: chia khung 1x, các profile máy yếu, HUD DOM là phần tốn kế tiếp.
- `GODOT.md` mục 7: gộp MeshInstance đứng yên, ảnh UI WebP.

## [0.26.8] - 2026-11-03

### Thêm

- `GAME-GUIDE.md` mục 17 "Quyền riêng tư: consent, Google DMA, Privacy Policy ở mọi vùng": lựa chọn của studio (3/11/2026) là mọi SDK tiếp tục đo và chia sẻ; app (webgame 0.54.0) gắn consent DMA của Google từ câu trả lời UMP vào lượt cài và mọi event của Adjust; Facebook không chờ consent (đánh đổi GDPR đã biết, do publisher chọn; game sau có thể quyết khác); game không phải viết gì. Settings luôn có link Privacy Policy cho mọi người chơi, không chỉ nút "Privacy settings" ở vùng GDPR (chính sách User Data của Google Play muốn link cả trong Play Console lẫn trong app; Crash Ramp v100s). Cùng luật trong `AGENTS.md` (luật 12, kiểm trước khi báo xong), `README.md` (phần quảng cáo), `GODOT.md` mục 6 và `GODOT-AGENTS.md` (luật 14). Game chưa có link Privacy Policy trong Settings thì thêm.

## [0.26.7] - 2026-11-03

### Thêm

- `GAME-GUIDE.md` mục 5, "Game online": vật thể rời tầm nhìn rồi quay lại là object mới cùng id, phải gắn lại hình (Ashlar: bóng ma đứng yên, quái thật vô hình); không dùng mốc thời gian âm như `time - 40`; cách kiểm.

## [0.26.6] - 2026-11-03

### Thêm

- `GAME-GUIDE.md` mục 5: cách sửa HUD bằng DOM giữ nguyên hình (Crash Ramp v100r: mỗi widget đổi mỗi khung một lớp ghép riêng với `will-change: transform`, ẩn canvas cả màn đang rảnh; A16 3x trên đường 31,6 lên 38,4 fps; kiểm bằng CDP `LayerTree`). "Đo cho đúng": Chrome headless trên Windows bị power throttling hạ xung sau khoảng một phút (Ashlar), cách tắt cho riêng cây tiến trình của trình duyệt test.
- `GAME-GUIDE.md` mục 17, cờ nước trong 3D: hai mặt cùng lấy mép trong ở phía cột (v100e), chỉ một lá cờ nước, sóng vải chạy từ cột ra (v100q), và A/B `nat_flag` đo D1 / D3 / D7.
- `GAME-GUIDE.md` mục 6: lượt hướng dẫn chỉ cho thấy những gì game thật có (Crash Ramp v100m: bỏ bức tường phuy nổ ở lượt đầu, lượt đầu hết đà như mọi lượt); bỏ một cái kết dựng sẵn thì đo lại bằng máy tự lái để lượt 2 đã nâng cấp vẫn đi xa hơn (tên lửa hướng dẫn 0,6 s thay vì 1 s).
- `GAME-GUIDE.md` mục 5: bảng "Một khung 3x đi vào đâu" của Crash Ramp trên Galaxy A16 (Mali-G68): bầu trời 4,4 ms, bloom 4,3 (pass lọc sáng 3,1), mặt đất 3,7, cây 3,4, hậu kỳ 2,0, bóng xe 1,2 trên khoảng 25 ms; đổi target gần như không tốn. Bài học varying của three trong `onBeforeCompile` (vẫn là `#include`, phải viết chunk ra trước) và kết quả varying 16 bit (2%, không đáng kể). "Đo cho đúng": cách đo GPU trên khung đứng yên (lượt A/A, xoay thứ tự, không đặt lượt rỗng trước lượt đo vì GPU hạ xung), và ba lỗi bench vẽ khác game.
- `GAME-GUIDE.md` mục 5: tách tiếp khung 3x của Crash Ramp v100j trên A16: bầu trời khoảng 29 chu kỳ mỗi điểm ảnh; cây tốn ở đỉnh (tắt ghi màu vẫn còn 3,0 trong 3,4 ms); pass lọc sáng của bloom nghẽn ở đọc texture half float có lọc (cảnh 8 bit: 0,3 thay vì 3,0 ms).
- `GAME-GUIDE.md` mục 5: số đo v100k (chỉ vẽ instance trong tầm nhìn, 0,7 ms) và v100l (nhiễu mây đọc qua bộ lọc texture, 1,2 ms), khung 3x còn khoảng 21 ms; quy đổi 1 chu kỳ mỗi điểm ảnh cả màn 3x khoảng 1,1 ms trên G68 MP2; gấp nhánh của map khác trước khi đọc đường dài nhất của malioc.
- `GAME-GUIDE.md` mục 5: sàn của khung khi không vẽ gì qua target HDR là 3,6 ms ở 3x (xoá canvas thẳng 0,5 ms); núi, ná, xu, hạt, chim khoảng 0; bóng xe 0,6 vẽ + 0,4 lấy mẫu; trời chiếm 42% điểm ảnh; bớt từng phần không cộng dồn.
- `GAME-GUIDE.md` mục 5: GPU mỗi khung theo độ nét trên A16 (3x 21,4 ms đến 2x 12,4 ms, bloom bật; trên đường 3x 33,8 fps, 2,5x 44,8 fps) và target cảnh R11F_G11F_B10F (nhanh hơn 2,1 ms nhưng lệch tối đa 6/255, trời thành bậc: đổi hình).
- `GAME-GUIDE.md` mục 5: HUD bằng DOM đổi mỗi khung là khoảng 8 ms mỗi khung trên A16 ở 3x khi đang chạy (ẩn HUD: 34,3 lên 48,7 fps, khung dài 27% xuống 3%); đọc xung và độ bận GPU Exynos qua `/sys/kernel/gpu` không cần root.

## [0.26.5] - 2026-11-02

### Thêm

- `GAME-GUIDE.md` mục 5: số đo nóng máy 10 phút của Crash Ramp trên Galaxy A16 (3x, 3x khoá 30, 2x, 2x khoá 30). Vẽ ít điểm ảnh hơn thì vừa mượt vừa mát hơn; khoá khung trong trang Chrome không làm mát, nên phải đo khoá khung trong app. "Đo cho đúng" có thêm cách đo nóng máy qua `adb shell dumpsys thermalservice`. Game không phải sửa gì.
- `GAME-GUIDE.md` mục 5, "Tìm phần nặng trong một shader": cách làm bản chẩn đoán cho Mali Offline Compiler, kèm số đo mặt đất Map 1 của Crash Ramp v100c trên Mali-G52 / G68 (phần màu đường khoảng một phần ba đường dài nhất, khối đá khoảng một phần sáu, nhiễu chi tiết và bóng nướng ít). Game không phải sửa gì.

## [0.26.4] - 2026-11-02

### Đổi

- GAME-GUIDE mục 17: bài học "Quốc gia của người chơi khi không có mạng" (Crash Ramp v100d, cờ nước ở vạch xuất phát): múi giờ trước, ngôn ngữ sau, múi giờ Windows dùng chung, cờ WebP xếp nối giải mã từng cờ, cờ hai mặt trong 3D. GODOT.md mục 7: cách làm trong Godot (`Time.get_time_zone_from_system()`, `OS.get_locale()`).

## [0.26.3] - 2026-11-02

### Thêm

- `godot/AGENTS.md` (từ `dev/GODOT-AGENTS.md`): quy tắc cho AI agent làm game Godot, cùng loại với `AGENTS.md` của game three.js: addon, `get_sdk()` cho kiểu chặt, mua hàng, lưu, `.pck`, hiệu năng, crash, build.
- `GAME-GUIDE.md` mục 21 "Crash và ANR sau khi ra mắt": app tự bắt gì, đọc cho đúng (người chơi thật, bản, robot, `renderer_gone` ở nền không phải crash, analytics lặp), bảng lỗi đã gặp và cách sửa, các bước cho mỗi lỗi mới. Thêm hai prompt cho agent: game chậm trên máy yếu, có crash mới.
- `GAME-GUIDE.md` mục 5: "Bớt việc CPU mỗi khung" (Crash Ramp v99c, v99d: `forceSinglePass` cho vật liệu cộng sáng hai mặt, `customDepthMaterial` dùng chung, sắp vật đặc theo program, camera bóng bao vật đang thấy; không bật tắt bóng giữa lượt); độ nét tự động tách đoạn khi nghỉ quá 5 giây (v99v); mở game nhanh đo từng bước và hiện menu trước (v98b, v98d); đo cho đúng (xen kẽ nhiều vòng, cảnh chậm dần, máy đo yên, `Math.random` lệch giữa hai bản, dòng crash lúc Test Lab dọn máy).
- `AGENTS.md` (game three.js) có mục "Hiệu năng và crash" (11 luật), kiểm thêm quảng cáo và Chrome 81 trước khi báo xong. `dev/GODOT.md` (`godot/README.md`) có mục 7 "Hiệu năng và lỗi" với số đo Butcher Defense (`.pck` 269 MB so với giới hạn 200 MB của Play, 11 giây nạp shader, RAM 1,44 GB).

### Đổi

- `@horus/godot` có `Horus.ads.busy()` (mỗi lúc một quảng cáo, như SDK web 0.26.1); ví dụ trong `godot/README.md` kiểm nó trước khi gọi rewarded.

## [0.26.2] - 2026-11-02

### Sửa

- `horus-build.mjs` gửi game trên 64 MB theo từng phần (`@horus/webgame` build-client): game Godot có `.pck` lớn build online được, trước đây Cloudflare từ chối mọi lần gửi trên 100 MB (HTTP 413). Khi gửi in `   gửi: NN%` cho thanh tiến trình của trang Build. Cần Worker `horus-build` mới (deploy cùng kit này).

## [0.26.1] - 2026-11-02

### Sửa

- `@horus/webgame` 0.52.1: mỗi lúc chỉ một quảng cáo. Bấm nút xem quảng cáo nhiều lần liền chỉ mở một quảng cáo; lần sau trả `reason: 'busy'` (rewarded) hoặc `busy: true` (inter). Có `platform.ads.busy()`. Cách viết nút quảng cáo: GAME-GUIDE đoạn "Mỗi lúc một quảng cáo".

### Thêm

- File SDK tự nạp vá cho WebView cũ (`.at()`, `replaceChildren`, `roundRect`, `animate()` keyframe thiếu đầu cuối, `getAnimations`) trước mọi thứ khác, nên game dùng SDK chạy được trên Chrome 80-86 mà không phải viết gì.

## [0.26.0] - 2026-11-02

### Thêm

- `horus-build.mjs` build được game Godot: `horus-game.json` có `"engine": "godot"` thì gửi file `.pck` đã export (`"pck"`: file hay thư mục chứa nó, không ghi thì tìm trong `build`, `export`, `dist` hay thư mục game). `--build-web` không có `"build"` thì gọi Godot của máy export bản `.pck` (preset `"exportPreset"`, mặc định `Android`). File `.pck` làm bằng Godot khác 4.7 bị từ chối ngay trên máy studio. Bản iOS cho game Godot chưa có.
- Gói SDK có thư mục `godot/` cho game Godot 4.7: `godot/addons/horus_sdk` (addon Horus SDK, `@horus/godot`, bỏ ghi chú như `horus-sdk.js` đã nén), `godot/example` (game mẫu Godot đủ project, có sẵn addon), `godot/README.md` (hướng dẫn tiếng Việt, `dev/GODOT.md`: cài, API so với SDK web, chạy thử trong editor, export `.pck`, gửi build, kiểm tra).
- SDK tự cập nhật (`horus-build.mjs` trước mỗi lần gửi, `update`) thay cả `horus-sdk/godot/` và addon `addons/horus_sdk` của game Godot khi `plugin.cfg` của gói mới hơn, cả thư mục một lần (ghi bên cạnh rồi đổi chỗ), bản cũ ở `horus-sdk/.old/<phiên bản>/`. Addon mới hơn của game thì để nguyên.

## [0.25.2] - 2026-11-02

### Đổi

- `dev/GAME-GUIDE.md` mục 5 thêm các bài học tối ưu từ Crash Ramp v98w đến v99n và Ashlar: "Độ nét tự động: bắt đầu nét nhất, chỉ hạ khi chậm thật", "Máy nóng khi chơi lâu" (giới hạn 30 khung/giây khi máy ấm, giữ nét; code mẫu chạy cả Android và iOS), "Mở game nhanh", "Đo cho đúng", "Game online: tải và mạng yếu"; ánh sáng theo đỉnh (A10 nhanh hơn 24%) chuyển từ "đã thử" sang "làm được"; bỏ lệnh vẽ rỗng.
- `dev/README.md`: luật nhiệt độ máy theo mục trên; iOS cũng báo nhiệt.

## [0.25.1] - 2026-11-01

### Đổi

- `@horus/webgame` ^0.51.0: iOS báo nhiệt độ máy (`platform.device.thermal`, sự kiện `'thermal'`) như Android, để game hạ tải khi iPhone ấm.

## [0.25.0] - 2026-10-29

### Thêm

- `app.InstanceWindow` (`@horus/app` ^1.4.0): một lệnh vẽ cho cả bộ cảnh vật chia đoạn dọc đường, chỉ các đoạn đang hiện nằm trong buffer (Crash Ramp v98o: Map 1 từ 104 xuống 76 draw call, cùng ảnh).
- `dev/GAME-GUIDE.md` mục 5: "Tối ưu GPU máy yếu, không đổi hình" (đo trên Test Lab, việc làm được, việc đã thử không ăn thua, cách kiểm chứng) và ngân sách draw call máy yếu dưới 80.

## [0.24.1] - 2026-10-29

### Đổi

- `@horus/webgame` ^0.50.0: lần mở đầu sau khi cài, Remote Config lấy và áp giá trị server trước khi `rc.values` trả lời (tối đa 2 giây); Android không còn bảng "Create a Play Games profile" che game lúc mở (`sdk.games.suppressProfileCreation`, mặc định bật).

## [0.24.0] - 2026-10-28

### Đổi

- `@horus/webgame` ^0.49.0: app Android có WebView cũ hơn `android.minWebView` (mặc định 80) hiện màn "cần cập nhật WebView" có nút mở Play thay vì chạy game; sự kiện `webview_old`, `webview_old_tap`, `webview_updated`.

### Tài liệu

- GAME-GUIDE: app Android của `@horus/webgame` 0.49.0 tự kiểm bản WebView (`android.minWebView`, mặc định 80): máy cũ hơn thấy màn cập nhật WebView có nút mở Play Store thay vì game đứng ở màn tải, và gửi `webview_old` để đếm số máy như vậy.

## [0.23.3] - 2026-10-28

### Tài liệu

- GAME-GUIDE: watchdog 30 giây của bộ nạp map không tính thời gian app ở nền (Crash Ramp v97g tải lại game khi người chơi chuyển app lúc mở lần đầu chậm); gọi `adLightOff` trong try/catch trước khi trao thưởng (một lỗi lúc vẽ lại đã làm mất thưởng ở v97g). Rút từ Crash Ramp v98a.

## [0.23.2] - 2026-10-28

### Tài liệu

- GAME-GUIDE: máy yếu và WebView cũ (build cho Chrome 80, polyfill tới Chrome 81, nạp map có giới hạn chờ và watchdog tải lại), game nhẹ khi quảng cáo che (bộ đệm vẽ 1x1, trả đúng pixel ratio cũ), trao lại thưởng `platform.ads.lost` lúc mở game, sự kiện chẩn đoán máy yếu, Firebase Test Lab trong mức miễn phí. Rút từ Crash Ramp v97d đến v97g.

## [0.23.1] - 2026-10-28

### Đổi

- `@horus/webgame` ^0.48.1: bản TestFlight gửi doanh thu quảng cáo như Play internal testing; iOS chỉ còn chặn bản Xcode và AppTransaction không xác minh được.

## [0.23.0] - 2026-10-28

### Đổi

- `@horus/webgame` ^0.48.0: doanh thu quảng cáo giả không còn tới Adjust, Firebase, Facebook: lượt hiển thị từ 1 USD trở lên (cả `adpaid` của trang), máy không cài từ Google Play (trừ bản debug, Play Games trên PC), APK ký lại, bản TestFlight / không phải App Store. Sự kiện `ad_revenue_blocked` ghi lý do. APK thử cài tay (LDPlayer) không còn gửi doanh thu: muốn thấy doanh thu thì cài qua Play internal testing.

## [0.22.1] - 2026-10-28

### Sửa

- `@horus/webgame` ^0.47.1: iOS cũng giữ thưởng quảng cáo khi tiến trình web bị tắt dưới quảng cáo (`platform.ads.lost`, `lostDone()`), và tiến trình web bị tắt lúc app ở nền chỉ còn sự kiện `renderer_gone`, không còn non-fatal.

## [0.22.0] - 2026-10-28

### Thêm

- `@horus/webgame` ^0.47.0: `platform.ads.lost` (`[{ pl, at }]`) và `platform.ads.lostDone()`. Android tắt renderer WebView trong lúc quảng cáo thưởng chạy thì người chơi xem hết vẫn được giữ thưởng: game mở lại đọc `ads.lost`, trao thưởng của từng placement rồi gọi `lostDone()`. Trong lúc quảng cáo che game, renderer giữ mức ưu tiên nên ít bị tắt hơn. Web và iOS: `[]`.

## [0.21.3] - 2026-10-28

### Sửa

- `@horus/webgame` ^0.46.3: renderer WebView bị Android tắt lúc app ở nền không còn là lỗi Crashlytics; mọi lần đều có sự kiện `renderer_gone` (`state` fg/bg, `crashed`).

## [0.21.2] - 2026-10-28

### Sửa

- `@horus/webgame` ^0.46.2: trên máy robot (Firebase Test Lab, Play pre-launch) Play Games không bật nên không còn bảng "Create a Play Games profile" che game; console của trang vào logcat. `@horus/app` ^1.3.2: màn phủ tải/lỗi phủ kín màn hình trên WebView cũ (Chrome dưới 87).

## [0.21.1] - 2026-10-27

### Sửa

- `@horus/webgame` ^0.46.1: nhịp hot update gửi tới khi vỏ tính lần mở là chạy được (không còn dừng sau 30 giây); lỗi JS chưa bắt báo vỏ `ok: false`.

## [0.21.0] - 2026-10-27

### Đổi

- `@horus/webgame` ^0.46.0: hot update không còn bỏ bản tốt khi người chơi mở rồi tắt nhanh (nhịp `app.hot.beat` sau `app.ready`); APK thử của game bật MAX Ad Review build được trở lại. Bản hot build từ SDK này mới gửi nhịp.

## [0.20.6] - 2026-10-27

### Đổi

- `@horus/webgame` ^0.45.2: APK test của Build online không còn gửi mapping R8 và native symbols lên Crashlytics của app thật.

## [0.20.5] - 2026-10-27

### Thêm

- `KIT`: bản horus-gamekit mà SDK này build ra (ghi lúc build). SDK Status có dòng `Horus SDK: <phiên bản> (kit <phiên bản>)` ngay dưới `Shell:`, trong email hỗ trợ và màn Tools của game. Gói kèm `@horus/webgame` 0.45.1 (sửa build TestFlight có MAX Ad Review hỏng ở bước archive).

## [0.20.4] - 2026-10-27

### Đổi

- Gói kèm `@horus/webgame` 0.45.0 (Ad Review cùng R8 và luật giữ subscriber Moloco, phía build Android; client JS không đổi).

## [0.20.3] - 2026-10-26

### Đổi

- Gói kèm `@horus/webgame` 0.44.0 (MAX Ad Review không cần dán key, phía build; client không đổi).

## [0.20.2] - 2026-10-26

### Đổi

- Gói kèm `@horus/webgame` 0.43.0 (hàng chờ build online nhẹ, phía server; client không đổi).

## [0.20.1] - 2026-10-26

### Sửa

- Thẻ Cập nhật nóng: ô bản store ghi một versionCode Android mỗi lần phát (webgame 0.42.0 từ chối danh sách nhiều bản); gói kèm webgame 0.42.0 (cập nhật nóng chắc hơn: bản hỏng sau `app.ready` tự quay về, `seq` chống phát lại bản cũ, giới hạn kích thước, renderer chết ở nền không tính lỗi).

## [0.20.0] - 2026-10-26

### Thêm

- Trang build (`HorusBuild.cmd`, `horus-build.mjs ui`) có thẻ **Cập nhật nóng** trên máy build của Horus: trạng thái, Phát bản nóng (build lại bản web trước), Lên %, Rút lại, Tắt / Bật, mỗi nút một lượt chạy có bước, % và nút Dừng. Máy của studio không có thẻ này, trang build của studio không đổi gì (cần webgame 0.41.0). Gợi ý: minor (0.20.0).
- `dev/GAME-GUIDE.md`: bài học Crash Ramp v87–v90 (60 khung/giây, nhạc .mp3, thông báo, mã quà, tham số `build`, robot, GAME_BUILD và cập nhật nóng); gói kèm `@horus/liveops` 1.1.0 (mã quà có trần `redeemCode`, tham số `build` trên mọi event, quay lại sau thông báo tính là phản hồi).

## [0.19.0] - 2026-10-26

### Thêm

- **Cập nhật nóng** (`platform.hot`, app build từ webgame 0.40.0): Horus phát bản web mới của game, app tải, kiểm chữ ký và chạy nó từ lần mở sau, không cần bản store; mặc định tắt, Horus bật cho từng game. `platform.hot.active` / `pending` / `check()` / `apply()`. Hướng dẫn: README mục 11.

## [0.18.1] - 2026-10-25

### Sửa

- Bản Android (webgame 0.39.0): file mapping R8 gửi Play kèm mỗi bản, stack trace crash/ANR đọc được trong Play Console; androidx.fragment 1.8.9 (Play hết cảnh báo thư viện fragment cũ).

## [0.18.0] - 2026-10-25

### Thêm

- `platform.share.open({ title, text, url, image })`: bảng chia sẻ của máy (ảnh, chữ, link) cho thẻ kết quả, thách đấu, mời bạn; web dùng `navigator.share` hoặc chép vào clipboard (webgame 0.38.0). Kiểu `ShareContent`, `ShareResult`.

## [0.17.0] - 2026-10-25

### Thêm

- Bắt crash rõ hơn (webgame 0.37.0): Android báo cả crash trong thư viện native (Crashlytics NDK, symbol tự gửi Firebase khi build); iOS báo treo máy, CPU quá tải và app bị hệ thống tắt (MetricKit) lên Crashlytics. Tắt NDK: horus-game.json / webgame.config.json `sdk.firebase-crashlytics.ndk: false`.

## [0.16.1] - 2026-10-25

### Sửa

- Debug symbols native gửi Play kèm bản Android (webgame 0.36.0): các thư viện native của SDK quảng cáo đã bị nhà cung cấp xoá symbol, nay kèm bảng symbol các hàm public của chúng để Play hết cảnh báo thiếu debug symbols.

## [0.16.0] - 2026-10-25

### Thêm

- Bản Android (AAB) có debug symbols native do Gradle đóng sẵn (webgame 0.35.0, horus-game.json `android.ndkVersion`, `android.debugSymbols`): Play hết cảnh báo "you've not uploaded debug symbols". Máy build cần NDK cài trong Android SDK.

## [0.15.0] - 2026-10-25

### Thêm

- horus-game.json `notif { sound, headsUp }`: âm thanh riêng và thông báo trồi đầu màn hình cho lời nhắc (webgame 0.34.0); lời nhắc Android chạy bằng báo thức nên đến đúng giờ hơn.

## [0.14.0] - 2026-10-25

### Thêm

- `platform.device.setFrameRate` / `display`, `platform.testLoop`, `platform.device.robot` (webgame 0.33.0, Android); README mục 9. Doanh thu IAP không mất / không tính hai lần, mã khuyến mãi và quà Play không tính là doanh thu (webgame 0.33.0, cloudsave 1.9.0).

## [0.13.1] - 2026-10-25

### Đổi

- Dùng `@horus/webgame` ^0.32.0 (debug symbols native gửi Google Play cùng AAB, bản tải Build online có `native-debug-symbols.zip`); SDK trong game không đổi.

## [0.13.0] - 2026-10-25

### Thêm

- iOS: `sdk.cloudsave.icloud` (webgame 0.31.0, cloudsave 1.8.0): mã người chơi đồng bộ qua iCloud Keychain, save theo Apple ID sang iPhone / iPad mới; README mục 8.

## [0.12.0] - 2026-10-24

### Thêm

- Play Games Recall: `platform.games.recall` / `recallSession()` (webgame 0.30.0) và cloud save tự mang save sang máy mới của cùng người chơi (cloudsave 1.7.0, xung đột có `recall: true`); README mục 8.

## [0.11.0] - 2026-10-24

### Thêm

- `platform.update` (`check`, `start`, `complete`, sự kiện `'update'`): cập nhật trong app của Google Play (module `update` của webgame 0.29.0, Android); README mục 11 có cách dùng.

## [0.10.0] - 2026-10-24

### Thêm

- `platform.device` (`gameMode`, `thermal`, `exits`), sự kiện `'gamemode'` / `'thermal'` và `platform.gameState()` (Android, webgame 0.28.0) trong `horus-sdk.d.ts`; README mục 9 có cách dùng.

## [0.9.1] - 2026-10-24

### Thêm

- Sự kiện `'trim'` (Android thiếu bộ nhớ, webgame 0.27.1) trong `horus-sdk.d.ts`; README mục 9 có cách dùng.

## [0.9.0] - 2026-10-24

### Thêm

- `platform.games.stats` và `platform.games.stat(name, props)`: Game Stats của Play Games cho chương trình Level Up (webgame 0.27.0, Android). README mục 11 có cách dùng.

## [0.8.0] - 2026-10-24

### Thêm

- horus-game.json `"iosIcons": { "tên": "file.png" }`: icon phụ của app iOS (PNG 1024×1024, không trong suốt) được gửi cùng bản build (`files/ios/AppIcon-<tên>.png`), để thử icon bằng Product Page Optimization của App Store.
- `platform.games.social`, `challenge()`, `activity()`, `play`, `takePlay()` và sự kiện `'gamesPlay'` (Game Center Challenges + Activities trên iOS 26, webgame 0.26.0) trong `horus-sdk.d.ts`.
- README mục 11: thách đấu và hoạt động Game Center; mục 12: khoá `iosIcons`.

## [0.7.0] - 2026-10-24

### Thêm

- `platform.games` (Game Center / Play Games, module `games` của @horus/webgame 0.25.0) và `platform.info.fontScale` trong `horus-sdk.d.ts` (từ `js/index.d.ts` của webgame khi build).
- README mục 11 (đổi tên "Đánh giá, bảng xếp hạng, shortcut, báo lỗi"): cách dùng `platform.games` và `platform.info.fontScale`.
- GAME-GUIDE bước 20 "Để được store feature": trợ năng (Reduce motion, Larger text, vùng chạm 48px), Game Center / Play Games, sự kiện mùa, việc trên App Store Connect và Play Console, đề cử.

## [0.6.4] - 2026-10-24

### Tài liệu

- README mục 13: bảng công cụ nêu đủ các phần của `app` (precompile, ShadowGate, createWorldUpdater, IdleScheduler, createPost, createPrompts, mergeParts, chụp PNG, GameLoop / Viewport / Overlay), `perf` (QualityGovernor, FramePacer, FrameStats, SectionTimer, deviceInfo, embedded / tapWatch / capCause), offer của `monetize`, `liveops.applyConfig`, `economy.growthFor` / `playProfile`, `fx.formatNumber` và sprite. Thêm `start({ cloudWait })`, `ads.simulate(fn, { loadMs })`, `usd` của `iap.finish` và `ltv_revenue`, danh sách user property có sẵn và `an.flush()`, `support.diag` / `report` / `mail`, dịch dòng trạng thái cloud (`STATUS_WORDS`, `ago`). Code không đổi.

## [0.6.3] - 2026-10-24

### Tài liệu

- README: mục 4 sự kiện `'purchase'` (đơn tới khi game đang chạy), `'prices'`, đơn `state: 'pending'` chưa giao (ví dụ cũ giao cả đơn pending từ `pending()`), đơn test (`test: true`); mục 7 `before` / `after` / `economy` / `version` / `omit` / `seal` / `fitArray` của kho lưu và nút xoá tiến độ (`wipe` + `save`); mục 8 kết quả `settleAtBoot`, xung đột giữa lúc chơi (sự kiện `'cloud'`, `takeCloud`, `keepLocal`), `cloud.sync()`, `cloud.enabled`; mục 13 ví dụ `liveops` (A/B, rương theo giờ, dời đồng hồ khi test). Code không đổi.

## [0.6.2] - 2026-10-24

### Tài liệu

- README bổ sung những tính năng chỉ có trong `horus-sdk.d.ts`: mục 3 giá trị quảng cáo (`ready()` `rvValue` / `interValue`, sự kiện `'adpaid'`), segment MAX (`ads.setSegments`), ad unit phụ (`ads.tags` / `ads.units`), `ads.mediationDebugger()`; mục 5 nguồn cài đặt (`platform.ua`, sự kiện `'ua'`) và `an.block` cho máy tester; mục 9 vùng an toàn (`--sat` / `--sab` / `--sal` / `--sar`, sự kiện `'insets'`), `platform.info`, `platform.target`, `platform.exit()`, `contact` khi không có mạng; mục 11 mới "Đánh giá, shortcut trên icon, báo lỗi" (`platform.review()`, `platform.shortcuts`, `platform.crash` / `crashKeys`). Build ra app thành mục 12, Logic game thành mục 13. Code không đổi.

## [0.6.1] - 2026-10-24

### Tài liệu

- README mục 10 mới "Thông báo (nhắc chơi và push)": xin quyền, đặt lịch khi ra nền và xoá khi quay lại, kênh `rewards` / `comeback` / `news`, số trên icon, mở đúng màn khi bấm (`notif.opened`, sự kiện `'notif'`), công tắc trong Settings (`notif.state()` / `settings()`), lịch có sẵn `liveops.planNotifications`, push Firebase, `notif_shown` / `notif_open`. Build ra app thành mục 11, Logic game thành mục 12. Code không đổi.

## [0.6.0] - 2026-10-24

### Thêm

- `platform.ads.ready()` có `rvValue` / `interValue` (giá ước tính USD một lượt của ad đã load) và `rvNet` / `interNet`; sự kiện `'adpaid'` mỗi lượt hiện MAX trả tiền; `platform.ads.setSegments({...})` (segment MAX từ lần mở app sau); `platform.ads.units(tags | '*')` + `platform.ads.tags` cho ad unit phụ (`rewardedExtra` / `interstitialExtra` trong cấu hình app, mặc định không dùng: 1 rewarded + 1 interstitial như cũ). Game cũ không đổi gì vẫn chạy y như trước; game mới nên kiểm tra hàm có không (`platform.ads.setSegments?.(...)`) để chạy được với app build trước 0.24.0.
- `platform.review()`: hộp đánh giá của Google Play / App Store ngay trong game, `{ shown }` (`shown: true` là đã hỏi store, không có nghĩa hộp thoại đã hiện), có trong `horus-sdk.d.ts`. Bản build của game cần bật đánh giá trong cài đặt trên máy build Horus; không bật và trên trình duyệt: `{ shown: false }`. Cần `@horus/webgame` 0.24.0.

### Đổi

- Đi kèm `@horus/webgame` ^0.24.0.

## [0.5.0] - 2026-10-23

### Thêm

- SDK tự cập nhật: mỗi lần gửi build, `horus-build.mjs` (và trang build) hỏi máy chủ build của Horus bằng mã build; có bản mới cùng major thì thay các file SDK trong `horus-sdk/` và các bản sao `horus-sdk.js` / `.mjs` / `horus-logic.mjs` khác của game, giữ bản cũ ở `horus-sdk/.old/<phiên bản>/`, trước khi build và gửi. Bản đổi lớn chỉ báo. `node horus-build.mjs update [--major]` cập nhật không cần build; `--no-update` hoặc `"sdkUpdate": false` trong `horus-game.json` để chỉ báo. README mục 10, AGENTS.md.
- `build.mjs`: `pack()` (và `--zip <file>`) ra đúng zip studio nhận (file dưới `horus-sdk/`, cùng SDK thì cùng byte).

### Đổi

- Đi kèm `@horus/webgame` ^0.23.0.

## [0.4.4] - 2026-10-23

### Đổi

- `GAME-GUIDE.md` (trong gói): từng bước làm một game như Crash Ramp, mỗi bước có "Xong khi"; AGENTS.md có mục "Làm game mới" trỏ tới nó.
- README mục 11: `fx.update(now / 1000)` (thời gian tính bằng giây, không phải dt).
- README bỏ mục Điều khoản; dòng đầu các file SDK chỉ còn `Horus SDK <phiên bản> | (c) Horus Entertainment`.

## [0.4.3] - 2026-10-23

### Sửa

- `horus-build.mjs` / trang build: mất mạng một lúc khi chờ máy build không còn làm dừng theo dõi job (dòng "mất kết nối tới máy chủ build, đang thử lại", rồi "đã kết nối lại"); chỉ dừng sau 15 phút không có câu trả lời. Đi kèm `@horus/webgame` 0.22.1.

## [0.4.2] - 2026-10-23

### Đổi

- Phụ thuộc `@horus/webgame` ^0.22.0.

## [0.4.1] - 2026-10-23

### Đổi

- Phụ thuộc `@horus/webgame` ^0.21.0.

## [0.4.0] - 2026-10-23

### Thêm

- Logic game và công cụ three.js của Horus trong SDK, dạng namespace: `monetize` (interstitial, chờ rewarded, bậc thiếu xu, Remote Config), `liveops` (ngày, quà, nhiệm vụ, thu nhập khi vắng, lịch thông báo, analytics phễu FTUE), `economy` (đường giá, BEST BUY, mô phỏng), `app` (vỏ game three.js), `fx` (hiệu ứng GPU), `perf` (governor chất lượng, khung hình). three.js không nằm trong SDK: game truyền `THREE` vào. README mục 11. `horus-sdk.js` lớn lên khoảng 117 KB.
- `horus-logic.mjs`: chỉ `monetize`, `liveops`, `economy`, không có platform: dùng trong Web Worker hay Node.
- Trang build và lệnh: `--build-web` / ô "build lại trước khi gửi" chạy `build` của `horus-game.json` (ví dụ `npm run build`) trên máy mình trước khi đóng gói, log hiện từng dòng, Dừng thì dừng luôn lệnh đó. Có `build` thì ô này bật sẵn.
- `HorusBuild.cmd` (Windows): bấm đúp là mở trang build. Game là thư mục kéo thả vào file, hoặc thư mục ngay trên `horus-sdk\` khi có `horus-game.json`, không thì game thử `example`. Báo khi chưa có Node 18+.

## [0.3.0] - 2026-10-23

### Thêm

- `node horus-build.mjs ui`: trang build trên trình duyệt, giống trang `npx webgame ui` của Horus: lưu mã build, sửa `horus-game.json`, kiểm tra bản web, gửi build (APK, AAB, lên Google Play, iOS lên TestFlight), từng bước và %, log, nút Dừng, job gần đây.
- `--play [--track internal|alpha|beta]`: máy build của Horus build AAB rồi đưa lên Google Play (version code tự tăng). `--ios`: build iOS trên Mac của Horus rồi lên TestFlight (số build tự tăng). Production không bao giờ từ đây.
- Mỗi lần gửi kèm link repo git của game (lấy từ `git remote origin`, không gửi user hay token), nhánh và commit. Horus có thể bắt buộc link repo: không có thì job bị từ chối. `horus-game.json` thêm `repo` (khi git không có remote) và `build` (lệnh build web, Horus dùng khi tự build từ source).
- Lúc chờ in các bước trên máy build của Horus kèm %. Ctrl+C dừng cả job trên máy build; `--cancel <mã>` dừng một job.

## [0.2.0] - 2026-10-22

### Thêm

- `horus-build.mjs`: build app không cần Android Studio. `node horus-build.mjs` gửi bản build web + `horus-game.json` + icon cho Horus và tải về APK (cài thử) hoặc AAB (`--aab`, lên Google Play). `--key` lưu mã build của team, `--dry-run` chỉ kiểm tra, `--no-wait` / `--job` gửi trước lấy sau. Cần Node 18+.
- `horus-game.json` có thêm `appId` (Horus cấp), `versionCode`, `web` (thư mục bản build), `icon`.
- `AGENTS.md`: quy tắc và lệnh cho AI agent (Claude Code, Cursor, Codex...) làm game với SDK.
- `example/` là một game đủ thư mục (có `horus-game.json` và `horus-sdk.js`): `node horus-build.mjs example` build thử được ngay.
- README mục 10 viết lại: Build online thay cho gửi zip bằng tay.

## [0.1.2] - 2026-10-22

### Sửa

- Dựng trên `@horus/webgame` 0.18.0. API và file SDK không đổi.

## [0.1.1] - 2026-10-22

### Sửa

- Dựng trên `@horus/webgame` 0.17.0. API và file SDK không đổi.

## [0.1.0] - 2026-10-22

### Thêm

- Bản đầu tiên: `horus-sdk.js` (global `HorusSDK`), `horus-sdk.mjs`, `horus-sdk.d.ts`. `start()`, `platform` (quảng cáo, mua hàng, analytics, Remote Config, vòng đời app, hỗ trợ, nhắc nhở, shortcut), `cloud` (cloud save), `save` (lưu game có phiên bản). Cùng một file chạy trên trình duyệt (quảng cáo và mua hàng giả lập) và trong app Horus build.
