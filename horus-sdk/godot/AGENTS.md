# AGENTS.md: game Godot dùng Horus SDK

Dành cho AI agent (Claude Code, Cursor, Codex, Copilot...) làm việc trong repo một game Godot phát hành cùng Horus. Người đọc cũng dùng được như một checklist. Hướng dẫn cho người: `README.md` cạnh file này (`horus-sdk/godot/README.md`). Tên field của kết quả và chú thích từng hàm: `horus-sdk.d.ts` của gói SDK (trong GDScript tên hàm viết `snake_case`, field giữ nguyên).

Đặt file này ở gốc repo game, hoặc thêm vào `AGENTS.md` / `CLAUDE.md` sẵn có một dòng: "Đọc horus-sdk/godot/AGENTS.md trước khi sửa quảng cáo, mua hàng, analytics, lưu game, hiệu năng hay build app."

Game three.js (HTML5) thì dùng `horus-sdk/AGENTS.md` thay cho file này.

## Bối cảnh

- Game dùng Godot **4.7** (app của Horus chạy 4.7.2; file `.pck` làm bằng bản Godot khác bị từ chối). Addon nằm ở `res://addons/horus_sdk`, plugin **Horus SDK** bật, autoload tên `Horus`.
- Horus build app Android từ file `.pck` game export. Repo này không cần code Android/iOS, Gradle hay khoá ký bản phát hành; plugin Android và template Gradle riêng của game không vào app Horus.
- Chỉ `.pck`, `horus-game.json`, icon và file Firebase được gửi, không gửi source. Id của app (ad unit MAX, Adjust, Facebook, licence key, `google-services.json` trùng `appId`) studio tự điền trong `horus-game.json` (README mục 12, "Id của app"); không tự bịa id. Hiện có Android; iOS và cập nhật nóng cho Godot chưa có.
- Trong editor addon chạy trình giả lập (`Horus.simulated` true): quảng cáo giả, mua giả, Remote Config mặc định. Game chơi trọn được không cần điện thoại.

## Quy tắc khi sửa code

1. `await Horus.start({skus = [...], rc_defaults = {...}})` một lần lúc mở game, rồi `Horus.ready()` khi màn đầu đã vẽ.
2. Rewarded: kiểm `Horus.ads.busy()` trước mọi việc trong hàm bấm nút; chỉ thưởng khi `(await Horus.ads.rewarded("<placement>")).ok`. Gặp `reason == "busy"` thì không đổi gì (quảng cáo trước còn đang mở). Placement viết chữ thường, có trong `ads.rewarded` / `ads.inter` của `horus-game.json`.
3. Mua hàng: giao hàng vào save và lưu (`store.save`) **trước**, rồi mới `Horus.iap.finish(...)`. Mỗi `token` giao một lần (ghi vào `buys`). Lúc mở game, giao hết `await Horus.iap.pending()`. `status == "invalid"` là đơn giả: không thưởng. App Horus đã kiểm đơn trước khi trả `"ok"`, nên trong app không cần server kiểm đơn riêng của game.
4. Lưu game qua `Horus.save_store({key, defaults})` (tự gửi bản sao cho app), và `store.restore_backup(Horus.save.backup)` trước `store.load()`. Chỉ lưu vào `user://` thì người chơi mất tiến độ khi cài lại.
5. `pause` / `resume` đến từ Horus (`reason` `"bg"`: rời game; `"ad"`: quảng cáo che game): lưu (`store.flush()`), dừng game, tắt nhạc tới `resume`. Không tự phát pause từ thông báo focus của Godot song song với Horus.
6. Không thêm plugin quảng cáo, thanh toán (`GodotGooglePlayBilling`...), Firebase, analytics hay tracking khác: app Horus đã có AppLovin MAX, Play Billing, Firebase, Crashlytics. Thêm vào là trùng số liệu, hoặc hai bên cùng giao một đơn.
7. Không sửa, format lại hay bọc lại file trong `addons/horus_sdk` và `horus-sdk/`: lệnh build thay nguyên thư mục khi có bản mới. Không commit `horus-sdk/.old/`.
8. Script mà công cụ `-s` biên dịch trước khi có autoload (test runner, smoke test) báo "Identifier not found: Horus", và game bật cảnh báo kiểu là lỗi (`unsafe_*`, `untyped_declaration`): lấy autoload có kiểu bằng `const HorusSDK := preload("res://addons/horus_sdk/horus.gd")` rồi `HorusSDK.get_sdk()`. Tham số public của addon khai `Variant`, truyền biến kiểu nào cũng được.
9. Analytics: `Horus.an.log(name, params)`, tên và tham số chữ thường `snake_case`, giá trị phẳng (số, chuỗi); ghi sự kiện mới vào `events` của `horus-game.json`. Mọi lần nhận hay tiêu tiền gọi `Horus.an.earn` / `spend`.
10. Remote Config: `Horus.rc.string(k)`, `number(k)`, `boolean(k)`, mặc định trong `rc_defaults` của `start()`; khoá mới ghi vào `remoteConfig` của `horus-game.json`.
11. Giá trên nút: `Horus.iap.price(sku)`, hoặc `Horus.iap.offer(sku)` (`{price, micros, currency}`) cho giá gạch ngang và analytics; chưa có giá thì hiện giá của game.
12. Nút back Android: `Horus.on_back(fn)`, `fn` trả true khi game đã dùng (đóng pop-up). Không dùng thì app về màn hình chính.
13. Mạng: `Horus.device.online()`; vùng an toàn (tai thỏ, thanh cử chỉ): `Horus.device.insets_px()`.
14. Settings luôn có link Privacy Policy cho mọi người chơi (`OS.shell_open("https://...")`), ở mọi vùng; thêm nút "Privacy settings" gọi `Horus.ads.privacy()` khi `Horus.ads.has_privacy`. Consent do app lo (cùng module với game web: Adjust mang consent DMA của Google, Facebook không chờ consent theo lựa chọn của studio): không gửi dữ liệu người chơi cho bên thứ ba từ GDScript.

## Hiệu năng và crash

Luật rút ra từ Butcher Defense (game Godot đầu tiên chạy Horus SDK, đo trên Galaxy A16, 11/2026) và Crash Ramp.

1. Game lên Google Play thì file `.pck` phải nhỏ hơn giới hạn 200 MB của phần cài chính. Butcher Defense ra 269 MB vì texture không nén (`compress/mode=0`, khoảng 110 MB texture). Texture lớn và texture 3D để **VRAM Compressed**, bật **Rendering > Textures > VRAM Compression > Import ETC2 ASTC**, giảm cỡ texture không cần to; xem lại cỡ `.pck` mỗi lần thêm art.
2. Lần mở đầu: Butcher Defense vào trận sau 20,5 giây, trong đó 11,1 giây là game tự nạp shader (46 material); gỡ app rồi cài lại thì mất cache shader và lên 15,4 giây. Gộp các material chỉ khác tham số, nạp shader sau màn đầu hoặc trong lúc người chơi ở menu, và đo lại trên máy thật sau khi gỡ app.
3. RAM: Butcher Defense dùng 1,44 GB (đồ hoạ 973 MB) trên Galaxy A16, nặng với máy 2-3 GB. Texture nén VRAM giảm cả RAM. Đo bằng `adb shell dumpsys meminfo <package>` lúc đang chơi.
4. Renderer **Compatibility**, tối đa 60 khung/giây; hướng màn hình cố định.
5. Không bao giờ hạ độ phân giải, tắt bóng hay tắt hiệu ứng để có fps mà người dùng chưa chọn. Máy ấm (`Horus.device.thermal`) thì giới hạn 30 khung/giây, giữ nguyên độ nét (mục 5 của `horus-sdk/GAME-GUIDE.md`).
5b. Quảng cáo thưởng có thể kết thúc bằng Android tắt cả app (máy 2-4 GB): ghi nhớ phần thưởng vào save trước quảng cáo, lần mở sau trả một lần khi `Horus.device.exits` có lần hệ thống tắt app 5 giây - 10 phút sau lúc quảng cáo bắt đầu; không bao giờ trả gem kiểu này (mục 8 của `GAME-GUIDE.md`).
6. Không kết luận fps từ máy ảo: chỉ điện thoại thật cắm USB, hoặc Firebase Test Lab trong quota miễn phí.
7. Lỗi script và `push_error` addon tự gửi lên Crashlytics (non-fatal, mỗi lỗi tối đa một lần mỗi phút): không cần viết thêm. Gắn chỗ người chơi đang đứng bằng `Horus.crash_keys({map = ..., screen = ...})` khi đổi màn.
8. Sửa crash theo mục 21 của `horus-sdk/GAME-GUIDE.md` (giống game web): đếm người chơi thật và bản, tìm bằng chứng (stack, sự kiện analytics trước lỗi), sửa kèm test; chỉ báo "đã hết lỗi" khi người chơi đã lên bản mới và Crashlytics không còn thấy.

## Test

- Chạy test của game trong editor hoặc headless với trình giả lập: `Horus.sim.cfg` (`buy_as`, `pending`, `prices`, `rc`, `connection`...) cho từng nhánh; test tự động thì `HorusFakeNative` đóng vai app (`Horus.attach(F)` trước `Horus.start()`, `F.emit("pause", {"reason": "bg"})`, `F.saved`).
- Game bật cảnh báo kiểu là lỗi: sau khi sửa, chạy công cụ kiểm script của game (Butcher Defense: một script `-s` nạp mọi file `.gd`).
- Trình giả lập giữ bản sao save ở `user://horus/backup.json` như app thật giữ sau khi cài lại: thử "cài mới" thì xoá cả file này cùng save của game.

## Build và gửi

```
# Godot: Project > Export, preset Android, Export PCK/ZIP... -> build/game.pck
node horus-sdk/horus-build.mjs --dry-run       # kiểm .pck (Godot 4.7, đủ project, có addon Horus), không gửi
node horus-sdk/horus-build.mjs                 # APK cài thử, về build-online/
node horus-sdk/horus-build.mjs --build-web     # Godot của máy export .pck trước rồi gửi
node horus-sdk/horus-build.mjs --aab           # AAB (chỉ khi Horus đã cài đặt game)
node horus-sdk/horus-build.mjs --play          # AAB lên Google Play internal (chỉ khi người dùng yêu cầu)
node horus-sdk/horus-build.mjs ui              # trang build cho người dùng (họ bấm, không phải agent)
```

- Người dùng muốn một trang để build (bấm build, xem tiến độ, tải app): mở `horus-sdk\HorusBuild.cmd` (Windows) hoặc `node horus-sdk/horus-build.mjs ui`. Agent không tự làm trang, server hay script build riêng thay cho chúng: trang có sẵn đúng luật của Horus (mã build, store, cập nhật SDK). API trong `BUILD-API.md` chỉ dùng cho việc trang không làm (bot báo tin, CI).
- `horus-game.json` có `"engine": "godot"`; thêm `"pck"` khi file không nằm trong `build`, `export` hay `dist`. Export tự động lấy Godot từ `"godot"` trong `horus-game.json`, biến `GODOT_BIN` hoặc `godot` trong PATH; preset `"exportPreset"` (mặc định `Android`).
- File trên 64 MB gửi theo từng phần, có %: `.pck` vài trăm MB mất vài phút là bình thường. Dùng `--no-wait` rồi `--job <mã>` nếu công cụ của agent giới hạn thời gian một lệnh.
- `--play` đưa app lên store: agent chỉ chạy khi người dùng yêu cầu rõ trong lượt đó. iOS cho game Godot chưa có.
- Mã build: người dùng chạy `node horus-sdk/horus-build.mjs --key <mã>` một lần, hoặc đặt `HORUS_BUILD_KEY`. Agent không tự tạo, không in, không ghi mã vào repo, log hay commit.
- SDK tự cập nhật khi gửi build: lệnh thay `horus-sdk/` và `addons/horus_sdk` của game, giữ bản cũ ở `horus-sdk/.old/`. Đọc `CHANGELOG.md` mới, mở lại project trong Godot, export lại `.pck` rồi gửi.
- `build-online/` là file tải về: để trong `.gitignore`.

## Kiểm tra trước khi báo xong

- Chơi trọn trong editor với trình giả lập: rewarded chỉ thưởng khi xem hết; chạm ba lần liền vào nút quảng cáo chỉ mở một quảng cáo; mua giả giao đúng một lần; chạy lại game, tiến độ và hàng đã mua còn.
- Test của game qua, kiểm script không lỗi.
- `horus-game.json` khớp code: mọi placement, SKU (giá USD, consumable), khoá Remote Config, sự kiện đều có.
- `node horus-sdk/horus-build.mjs --dry-run` không còn dòng `chú ý:`; `.pck` dưới 200 MB nếu game lên Play.
- Settings có link Privacy Policy mở được, không phụ thuộc `Horus.ads.has_privacy`.
- Trên điện thoại Android thật với APK thử: mở lần đầu sau khi gỡ app (ghi thời gian tới lúc chơi được), Home rồi mở lại giữ nguyên trận, nút back đúng, `adb logcat` không có `SCRIPT ERROR`.

## Ví dụ

`godot/example/` trong gói SDK là một project Godot đủ: xu, quảng cáo thưởng, mua hàng, lưu game, cloud save, nhắc nhở. Mở bằng Godot 4.7, export `build/game.pck`, rồi `node horus-build.mjs godot/example`.

## Gọi máy chủ build

Cần trạng thái job, vị trí trong hàng chờ (`queuePosition`, `jobsAhead`), dừng job hay tải app từ code hay script: đọc `horus-sdk/BUILD-API.md`, không đoán API. Mã build lấy từ biến `HORUS_BUILD_KEY` hay file mã đã lưu, không bao giờ ghi vào repo.
