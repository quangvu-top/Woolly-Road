# Horus SDK cho Godot

Game làm bằng Godot 4.7 dùng được Horus SDK như game web: quảng cáo AppLovin MAX, mua trong app, analytics, Remote Config, lưu game có bản sao trong app và cloud save, nhắc nhở, dịch vụ game, cập nhật trong app, báo lỗi. Horus build app Android từ file `.pck` anh/chị export, giống cách Horus build từ bản web.

Hiện có: **Android**. Chưa có: bản iOS (Horus đang làm) và cập nhật nóng (game Godot cập nhật qua store).

Trong gói SDK, thư mục `godot/` có:

| File | Là gì |
| --- | --- |
| `godot/addons/horus_sdk/` | Addon Horus SDK: chép vào `res://addons/horus_sdk` của game |
| `godot/example/` | Game mẫu Godot đủ một project: xu, quảng cáo thưởng, mua hàng, lưu game, cloud save, nhắc nhở |
| `godot/README.md` | File này |
| `godot/AGENTS.md` | Quy tắc cho AI agent (Claude Code, Cursor, Codex...) làm game Godot: chép vào gốc repo game |

## 1. Cài vào game

1. Dùng Godot **4.7** (app của Horus chạy Godot 4.7.2; file `.pck` làm bằng bản Godot khác bị từ chối).
2. Chép `godot/addons/horus_sdk` vào `res://addons/horus_sdk` của game.
3. **Project > Project Settings > Plugins**: bật **Horus SDK**. Plugin thêm autoload `Horus`.
4. Renderer nên là **Compatibility** (nhẹ nhất cho máy yếu). Hướng màn hình cố định (`display/window/handheld/orientation`), giống `orientation` trong `horus-game.json`.

Không cần cấu hình gì khác. Trong app Horus, addon tự tìm cầu nối của app. Trong editor, addon chạy trình giả lập để chơi trọn game (mục 4).

## 2. Dùng nhanh

```gdscript
var store: HorusSaveStore
var game := {}

func _ready() -> void:
	store = Horus.save_store({key = "mygame", defaults = func(): return {coins = 0, level = 1, buys = []}})
	await Horus.start({skus = ["coins_100", "remove_ads"], rc_defaults = {inter_every = 3}})
	store.restore_backup(Horus.save.backup)       # máy mới, cài lại: lấy bản app giữ
	game = store.load()
	for p in await Horus.iap.pending():           # đơn đã trả tiền mà chưa giao (app tắt giữa chừng)
		grant(p)
	Horus.pause.connect(func(d): store.flush())   # "bg": người chơi rời game; "ad": quảng cáo che game (tắt nhạc)
	Horus.on_back(func(): return close_popup())   # nút back: true là game đã dùng
	Horus.ready()                                 # game đã lên màn hình

func double_coins() -> void:
	if Horus.ads.busy():                          # chạm lần hai khi quảng cáo đang mở: không làm gì
		return
	var r := await Horus.ads.rewarded("double_coins")
	if r.ok:                                      # chỉ thưởng khi xem hết
		game.coins *= 2
		store.queue(game)

func buy(sku: String) -> void:
	var b := await Horus.iap.buy(sku)
	if b.status == "ok":
		grant(b)

func grant(p: Dictionary) -> void:
	if not game.buys.any(func(x): return x.token == p.token):
		game.coins += 100
		game.buys.append({sku = p.sku, token = p.token})
		store.save(game)                          # giao hàng vào save trước...
	Horus.iap.finish({sku = p.sku, token = p.token, orderId = p.get("orderId", ""), consumable = true, usd = 0.99})   # ...rồi finish
```

Mọi lời gọi có giá trị dự phòng và timeout: app không có quảng cáo thì `rewarded` trả `ok` false, cầu nối lỗi thì mua trả lỗi. Không lời gọi nào treo game hay cho mua miễn phí.

## 3. API

Tên giống SDK web, viết kiểu `snake_case`; hàm trả Promise trong JS thì `await` trong GDScript. Khoá của kết quả giữ đúng như SDK web (`orderId`, `rvValue`, `signedIn`...), nên tài liệu API của SDK web (trang Tham chiếu API) vẫn đúng cho các field.

| SDK web | GDScript |
| --- | --- |
| `await HorusSDK.start({ skus })` | `await Horus.start({skus, cloud = true, cloud_wait = 3000, rc_defaults = {}})` (một lần) |
| `platform.ready()`, `platform.onBack(fn)`, `platform.exit()` | `Horus.ready()`, `Horus.on_back(fn)`, `Horus.exit()` |
| `platform.on('pause', fn)` | `Horus.on("pause", fn)` hoặc signal `Horus.pause` |
| `platform.info`, `platform.kind` | `Horus.info` (thêm `density`: pixel mỗi dp), `Horus.target` (`"android"`, `"web"` khi giả lập) |
| `platform.ads.rewarded(pl)`, `.inter(pl)`, `.ready()`, `.busy()`, `.privacy()` | `Horus.ads.rewarded(pl)` → `{ok, reason}`, `inter(pl)` → `{shown}`, `ready()`, `busy()`, `privacy()`, `has_privacy`. Mỗi lúc một quảng cáo: gọi lần hai khi quảng cáo trước còn mở thì trả ngay `reason` `"busy"` (inter: `busy` true), analytics có `ad_dup` |
| `platform.iap.buy`, `.pending`, `.finish`, `.restore`, `.price` | `Horus.iap.buy(sku)`, `pending()`, `finish(p)`, `restore()`, `price(sku)`; thêm `offer(sku)` → `{price, micros, currency}` (giá gạch ngang, doanh thu theo tiền của người chơi) |
| `platform.an.log`, `.user`, `.earn`, `.spend`, `.result` | `Horus.an.log(name, params)`, `user`, `earn`, `spend`, `result` |
| `platform.rc.values` | `Horus.rc.values`, thêm `rc.string(k)`, `rc.number(k)`, `rc.boolean(k)` |
| `platform.save.backup`, `.mirror(json)`, `.flush()` | `Horus.save.backup`, `mirror(json)`, `flush()` |
| `save.createSaveStore(o)` | `Horus.save_store(o)` (tự gửi bản sao cho app) hoặc `HorusSaveStore.new(o)` |
| `platform.cloud.status()`, `.useCloud()`, `.keepLocal()`, `.sync()` | `Horus.cloud.status()`, `use_cloud()`, `keep_local()`, `sync()` |
| `HorusSDK.cloud.settleAtBoot(platform, rules)`, `statusText(s)` | `Horus.cloud.settle_at_boot(rules)`, `status_text(s)` |
| `save.conflictRules`, `save.further`, `save.mergePurchases` | `HorusSaveStore.conflict_rules`, `further`, `merge_purchases` |
| `platform.notif.ask`, `.schedule`, `.cancelAll`, `.opened` | `Horus.notif.ask()`, `schedule(list)`, `cancel_all()`, `opened` |
| `platform.games.submit`, `.unlock`, `.show`, `.signIn` | `Horus.games.submit`, `unlock`, `show`, `sign_in` |
| `platform.review()`, `.haptic(p)`, `.crash(msg)` | `Horus.review()`, `haptic(p)`, `crash(msg, stack)` |
| `platform.support.mail(m)`, `.diag()` | `Horus.support.mail(m)`, `diag()` |
| `platform.native.call(m, a)` | `Horus.native.request(m, a)` |
| `navigator.onLine` | `Horus.device.online()`, `Horus.device.connection` (`"wifi"`, `"cellular"`, `"none"`...), `await Horus.device.check_connection()` (hỏi lại lúc cần) |
| Insets (`--sat`, `--sab`...) | `Horus.device.insets` (dp), `Horus.device.insets_px()` (pixel), signal `Horus.insets` |
| `monetize`, `liveops`, `economy` | `Horus.monetize`, `Horus.liveops`, `Horus.economy` |

Script không viết được `Horus` (script mà công cụ `-s` như test runner, smoke test biên dịch trước khi có autoload, báo "Identifier not found: Horus"), và game bật cảnh báo kiểu là lỗi: lấy autoload có kiểu sẵn bằng `get_sdk()`.

```gdscript
const HorusSDK := preload("res://addons/horus_sdk/horus.gd")
var r := await HorusSDK.get_sdk().ads.rewarded("double_coins")
```

Sự kiện: `Horus.on(tên, fn)` với tên như SDK web, hoặc signal cùng tên. Sự kiện trùng tên một phần API có `_event` phía sau: `ads_event`, `notif_event`, `games_event`, `update_event`, `cloud_event`, `ua_event`; `gamesPlay` là `games_play`.

Cloud save lúc mở game, trước `store.load()`:

```gdscript
await Horus.cloud.settle_at_boot(HorusSaveStore.conflict_rules(store, {
	further = HorusSaveStore.further("level", "coins"),
	merge = func(into, from): return HorusSaveStore.merge_purchases(into, from, {credit = credit}),
	mirror = Horus.save.mirror, flush = Horus.save.flush,
}))
```

Save viết ra cùng định dạng với SDK web (thứ tự khoá, cách viết số), nên bản sao trong app và cloud save chạy như game web.

## 4. Chạy thử trong editor

Ngoài app, `Horus.simulated` là true và game chơi trọn được:

- Quảng cáo: lớp phủ giả sẵn có (nút nhận thưởng mở sau 3 giây), hoặc quảng cáo giả của game: `Horus.ads.simulate(func(kind, placement): return await show_fake_ad(), {load_ms = 1500})`.
- Mua: thành công sau 700 ms, không trừ tiền (`test` true). Thử nhánh khác: `Horus.sim.cfg.buy_as = {"coins_100": "cancel"}` (`"error"`, `"pending"`, `"invalid"`).
- Remote Config: giá trị `rc_defaults` của `start()`; `Horus.sim.cfg.rc` đè lên.
- `pause` / `resume`: khi cửa sổ mất focus hay đóng, như app.

Test tự động không cần điện thoại: `HorusFakeNative` (trong addon) đóng vai app.

```gdscript
var F := HorusFakeNative.new({prices = {"coins_100": "$0.99"}})
Horus.attach(F)                    # trước Horus.start()
await Horus.start({skus = ["coins_100"]})
F.emit("pause", {"reason": "bg"})  # lái game như app
assert(F.saved != null)            # bản sao save app đã nhận
```

## 5. Export file .pck và gửi build

1. Godot: **Project > Export**, thêm preset **Android**.
2. **Export PCK/ZIP...**, chọn đuôi `.pck`, lưu vào thư mục `build` của game (ví dụ `build/game.pck`). Bước này chỉ đóng gói tài nguyên của game, không cần Android SDK hay keystore: Horus build và ký app.
3. `horus-game.json` ở gốc thư mục game có `"engine": "godot"` (xem `godot/example/horus-game.json`).
4. Gửi build như game web: bấm đúp `horus-sdk\HorusBuild.cmd` (trang build), hoặc `node horus-sdk/horus-build.mjs .` trong thư mục game.

Lệnh tìm file `.pck` theo `"pck"` trong `horus-game.json` (file hay thư mục chứa nó), không ghi thì lấy file `.pck` duy nhất trong `build`, `export`, `dist` hay thư mục game. Lệnh kiểm file trước khi gửi: đúng Godot 4.7, có `project.binary` (cả project, không phải bản patch), có addon Horus. Chỉ file `.pck`, `horus-game.json`, icon và file Firebase của game (`google-services.json`) được gửi, không gửi source game. Id của app (ad unit MAX, Adjust, Facebook, licence key, file Firebase) studio tự điền vào `horus-game.json` như game web: README mục 12, "Id của app" (từ SDK 0.27.0).

Export tự động: `--build-web` (hay ô **build lại trước khi gửi** trên trang build) gọi Godot của máy export file `.pck` trước khi gửi. Godot lấy từ `"godot"` trong `horus-game.json` (đường dẫn tới file chạy Godot), biến `GODOT_BIN`, hay `godot` trong PATH; preset là `"exportPreset"`, mặc định `Android`.

SDK luôn mới: như game web, mỗi lần gửi build lệnh hỏi Horus có SDK mới không. Có bản mới cùng major thì lệnh thay `horus-sdk/` (cả `horus-sdk/godot/`) và addon `addons/horus_sdk` của game khi addon của gói mới hơn, giữ bản cũ ở `horus-sdk/.old/<phiên bản>/`. Mở lại project trong Godot sau khi addon đổi.

Thử ngay với game mẫu: mở `godot/example` bằng Godot 4.7, chạy thử trong editor, export `build/game.pck`, rồi `node horus-build.mjs godot/example`.

## 6. Kiểm tra trước khi gửi

- Có `await Horus.start(...)` một lần lúc mở game và `Horus.ready()` khi game lên màn hình.
- Rewarded chỉ thưởng khi `ok`; nút quảng cáo kiểm `Horus.ads.busy()` trước, chạm ba lần liền chỉ mở một quảng cáo; mua hàng lưu vào save trước, `finish` sau; có xử lý `pending()` lúc mở game.
- `pause`: lưu game (`store.flush()`); `reason == "ad"`: tắt nhạc tới `resume`.
- Nút back: `Horus.on_back` trả true khi đóng pop-up; game không dùng thì app về màn hình chính.
- Chừa chỗ cho tai thỏ và thanh cử chỉ bằng `Horus.device.insets_px()`.
- Không tự thêm plugin quảng cáo, analytics hay thanh toán khác.
- Settings có link Privacy Policy cho mọi người chơi, ở mọi vùng (`OS.shell_open("https://...")`, đúng URL khai trên store; Google Play muốn link cả trong Play Console lẫn trong app), và nút "Privacy settings" gọi `Horus.ads.privacy()` khi `Horus.ads.has_privacy` (vùng GDPR). App Android của game Godot dùng cùng module với game web: Adjust gắn consent DMA của Google từ câu trả lời form consent, Facebook không chờ consent (lựa chọn của studio, webgame 0.54.0, GAME-GUIDE mục 17); game không phải viết gì.
- Consent và cờ DMA của Google do app (vỏ Android) lo, game Godot không viết gì; cách đọc số liệu UA sau consent (camp Google ở EEA, Organic, `consent_state`, không gửi `ad_user_data=1` cho người từ chối): GAME-GUIDE.md mục 17.
- Game lên Google Play: `.pck` dưới 200 MB (mục 7).

## 7. Hiệu năng và lỗi

Số đo từ Butcher Defense, game Godot đầu tiên chạy Horus SDK (Galaxy A16, 11/2026):

| Đo | Butcher Defense | Nên làm |
| --- | --- | --- |
| Cỡ `.pck` | 269 MB, trong đó khoảng 110 MB texture không nén (`compress/mode=0`) | Phần cài chính trên Google Play tối đa 200 MB. Texture lớn và texture 3D để **VRAM Compressed**, bật **Rendering > Textures > VRAM Compression > Import ETC2 ASTC**, bỏ texture to không cần |
| Từ lúc mở tới lúc chơi | 20,5 giây, trong đó 11,1 giây game tự nạp shader (46 material); 15,4 giây nạp shader sau khi gỡ app (mất cache) | Gộp material chỉ khác tham số, nạp shader sau màn đầu hoặc lúc người chơi ở menu, đo lại sau khi gỡ app |
| RAM khi chơi | 1,44 GB, đồ hoạ 973 MB | Nặng với máy 2-3 GB; texture nén VRAM giảm cả RAM. Đo bằng `adb shell dumpsys meminfo <package>` |
| Mở app (cold start) | 574 ms | |
| Crash, ANR, lỗi script | không có | |

Thêm:
- Renderer **Compatibility**, tối đa 60 khung/giây. Máy ấm (`Horus.device.thermal`) thì giới hạn 30 khung/giây và giữ nguyên độ nét; không hạ độ phân giải hay bỏ hiệu ứng khi chưa được chủ game đồng ý (cùng luật với game web, `GAME-GUIDE.md` mục 5).
- Vật nhỏ nhiều mảnh đứng yên: gộp các `MeshInstance3D` thành một mesh mỗi vật liệu (mỗi lệnh vẽ tốn CPU trên máy yếu; cùng bài học trong GAME-GUIDE mục 5). Ảnh UI có alpha: import WebP (lossy, chất lượng khoảng 0,9) thay vì PNG để app nhỏ hơn.
- fps chỉ tin số đo trên điện thoại thật (cắm USB, hoặc Firebase Test Lab trong quota miễn phí), không tin máy ảo.
- Lỗi script và `push_error` addon tự gửi lên Crashlytics (non-fatal, mỗi lỗi tối đa một lần mỗi phút). Gắn chỗ đang đứng bằng `Horus.crash_keys({map = ..., screen = ...})`. Đọc và sửa crash như game web: `GAME-GUIDE.md` mục 21.
- Quốc gia của người chơi khi không có mạng: cách làm như game web (`GAME-GUIDE.md` mục 17, múi giờ trước, ngôn ngữ sau). Trong Godot, `Time.get_time_zone_from_system()` trả độ lệch và tên múi giờ, nhưng tên đó không phải lúc nào cũng là id IANA: kiểm trên điện thoại Android thật trước khi dựa vào nó; vùng của `OS.get_locale()` là đường lui.
- Quy tắc ngắn cho AI agent: `godot/AGENTS.md`.
