# API của máy chủ build Horus (Build online)

`horus-build.mjs` và trang HorusBuild dùng các API này. **Đã có sẵn trang build**: bấm đúp `horus-sdk\HorusBuild.cmd` (Windows) hoặc chạy `node horus-sdk/horus-build.mjs ui` để build, theo dõi tiến độ và tải app. Đừng tự làm một trang build khác. Chỉ gọi thẳng các API dưới đây cho việc trang đó không làm: bot báo build vào nhóm chat, CI. Tên trường giữ tiếng Anh, đúng như JSON máy chủ trả về.

- Địa chỉ: `https://horus-build.horus-production.workers.dev` (biến môi trường `HORUS_BUILD_SERVER` đổi được).
- Xác thực: header `Authorization: Bearer <mã build>`, đúng mã đã lưu bằng `node horus-build.mjs --key <mã>`. Mã chỉ thấy job của team mình (job của team khác: 403).
- Trả về JSON (trừ file zip). Lỗi: mã HTTP 4xx/5xx và `{ "error": "..." }`.
- Không gọi dồn: hỏi trạng thái một job mỗi 4 đến 5 giây là đủ.

## Gửi một bản build

`POST /jobs`: body là file zip (`horus-game.json`, `dist/...`, `files/icon.png`, đúng dạng `horus-build.mjs` đóng gói). Header `x-build-meta` = base64 của JSON:

| Trường | Ý nghĩa |
| --- | --- |
| `app`, `package` | Tên game, `appId` (package Android) |
| `platform` | `android` (mặc định) hoặc `ios` |
| `output` | `apk` (mặc định) hoặc `aab` |
| `store`, `track` | `play` + `internal` / `alpha` / `beta` (Android lên Google Play), `testflight` (iOS). Không bao giờ `production` |
| `sdk`, `version` | Bản Horus SDK của game, phiên bản game |
| `source` | `{ repo, branch, commit, dirty }`: repo git của game |

Trả về `{ "id": "<mã job>" }`. Bản build trên 100 MB một lần gửi: `POST /jobs/parts` (header `x-build-meta`, `x-build-size`) trả `{ id, upload, part }`, rồi `PUT /jobs/<id>/src.zip?upload=<u>&part=<n>` từng phần (`part` byte, phần cuối ít hơn) trả `{ part, etag }`, cuối cùng `POST /jobs/<id>/src.zip?upload=<u>` với body `{ "parts": [{ "part", "etag" }] }`. Tối đa 256 MB.

## Theo dõi một job

`GET /jobs/<id>`:

| Trường | Ý nghĩa |
| --- | --- |
| `id`, `app`, `platform`, `output`, `store`, `track` | Như lúc gửi |
| `status` | `pending` (đang xếp hàng), `building`, `done`, `failed`, `cancelled` |
| `queuePosition` | (SDK 0.30.0) Job đang xếp hàng: vị trí trong hàng, `1` là job kế tiếp máy build lấy. Không xếp hàng nữa: `null` |
| `jobsAhead` | (SDK 0.30.0) Số job đang chờ được gửi trước job này, mọi team, cả Android và iOS (máy build làm lần lượt, cũ trước). Không tính job máy build đang làm dở. Không xếp hàng nữa: `null` |
| `progress` | Khi đang build: `{ step, steps, what, pct, detail, at }` (bước thứ mấy trên bao nhiêu, đang làm gì, phần trăm) |
| `at`, `started`, `ended` | Lúc gửi, lúc máy build bắt đầu, lúc xong (ISO) |
| `uploaded` | Bản lên store: Google Play (track, version code) hay TestFlight (số build) |
| `result` | File kết quả khi có (`out.zip`) |
| `cancel` | `true` khi đã bấm dừng |
| `log`, `error` | Log cuối và lỗi khi `failed` |
| `kind`, `by`, `source` | Loại job, người gửi, repo |

Ví dụ:

```bash
curl -s -H "Authorization: Bearer $HORUS_BUILD_KEY" https://horus-build.horus-production.workers.dev/jobs/<id>
# { "id": "...", "status": "pending", "queuePosition": 3, "jobsAhead": 2, "progress": null, ... }
```

## Dừng, tải kết quả

- `POST /jobs/<id>/cancel`: job đang chờ thì dừng ngay; đang build thì máy build kết thúc nó (bản lên Play làm dở được xoá). Trả `{ status }`; job đã xong: 409.
- `GET /jobs/<id>/out.zip`: app đã build (APK / AAB và file đi kèm). Chưa có: 404. iOS lên TestFlight không có file tải.

## Bản Horus SDK mới nhất

- `GET /sdk`: `{ version, file, size, sha256, at }` của Horus SDK mới nhất (404 khi chưa có).
- `GET /sdk/horus-sdk-<version>.zip`: gói SDK đó. `node horus-build.mjs update` dùng hai API này.
