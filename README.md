# AoE Ranking — Bảng xếp hạng ELO nội bộ team

Web tính điểm ELO riêng cho các thành viên team dựa trên API lịch sử đấu GPlay.
**Miễn phí hoàn toàn, không cần thẻ tín dụng** (dùng GitHub Actions + GitHub Pages).

## Luật tính ELO

- ELO mỗi thành viên **bắt đầu từ 1000** (mốc trung bình, chuẩn quốc tế) và **không bao giờ
  âm**. Chỉ tính các trận trong **6 tháng gần nhất** (cửa sổ trượt, cấu hình `WINDOW_MONTHS`
  trong `scripts/team.mjs`). Mỗi lần cập nhật tính lại toàn bộ cửa sổ này — trận cũ hơn
  6 tháng tự rơi ra.
- Chỉ tính trận **nội bộ**: TẤT CẢ người chơi của cả 2 đội đều là thành viên team.
- Loại **trận "ma"**: (1) chỉ có 1 người chơi hoặc một đội rỗng (Xv0 — không có đối thủ), hoặc
  (2) tổng `kills + losses` (giết + mất quân) của tất cả người chơi `< 10` (không có giao tranh thật).
- **Trùng màu (`empires_color`)**: nếu nhiều người cùng 1 màu/slot, chỉ **người đầu tiên** (theo thứ tự
  danh sách) được tính ELO; những người sau là **viewer**, không tác động (không tính trận/thắng/thua).
  Số người thực mỗi đội (sau khi bỏ viewer) cũng dùng để xác định thể loại 1v1/2v2/3v3/4v4.
- **Performance ELO** (không chỉ thắng/thua): mỗi trận, từng chỉ số (giết/mất quân, phá công trình,
  đào vàng, dân số, công nghệ, tốc độ lên đời, mở bản đồ, bơm đồ...) được chuẩn hoá tương đối giữa
  những người cùng trận thành `perf ∈ [0,1]`. Điểm nhận `S = 0.5·(thắng?1:0) + 0.5·perf`,
  cập nhật `Δ = K·(S − E)` với `E` là kỳ vọng theo ELO trung bình 2 đội.
  Thắng/thua lấy từ `statistics.result` (KHÔNG dùng `victory_team_idx` — field này luôn = 0).
- **K thích ứng** (mỗi bảng): 10 trận đầu `K = 40` — định hạng nhanh về đúng trình độ;
  từ trận 11 `K = 24` — ổn định, ít nhiễu. Dưới 10 trận web hiển thị nhãn **"ELO tạm"**
  (chưa đủ tin cậy); chưa có trận ở bảng nào thì bảng đó hiện "—" và xếp cuối.
- **Độ quen tay** (trọng số nhỏ): ELO hiển thị cộng thêm `ACTIVITY_WEIGHT × √games`
  (mặc định 1: 100 trận → +10, 200 trận → +14). Cấu hình trong `scripts/team.mjs`.
- **Điểm giải đấu** (trọng số nhỏ): các giải trên web **đã bấm "Kết thúc giải"** — mỗi
  thành viên đội vô địch **+15**, á quân **+7** điểm ELO (`TOURNEY_BONUS` trong
  `scripts/team.mjs`), cộng vào bảng Tổng và bảng thể loại của giải (1v1/2v2/...).
  Chỉ tính giải kết thúc trong **cửa sổ trượt 1 năm** (`TOURNEY_WINDOW_MONTHS`) — dài hơn
  cửa sổ trận đấu vì thành tích giải đáng nhớ lâu hơn, nhưng vẫn rơi ra theo thời gian để
  người đã nghỉ chơi không giữ điểm mãi. Mốc tính là lúc bấm "Kết thúc giải" (giải kết thúc
  từ trước khi có mốc này thì tạm lấy ngày tạo giải).
  Script đọc kết quả giải từ Firebase RTDB qua REST; Firebase lỗi thì bỏ qua phần này,
  không ảnh hưởng cập nhật ELO.
- Xếp hạng theo ELO giảm dần (hạng 1, 2, 3...).
- Ngoài ELO **Tổng**, còn tính ELO **riêng cho từng thể loại 1v1 / 2v2 / 3v3 / 4v4** (chỉ trận
  cân người; trận lệch như 3v4 chỉ tính vào Tổng). Web có nút chọn chế độ để xem từng bảng.
- Tự chạy **7:00 / 14:00 / 21:00 hàng ngày** (giờ VN) bằng GitHub Actions cron, và chạy lại
  mỗi khi push thay đổi vào `app/**` hoặc `scripts/**`.

## Kiến trúc

```
AOE_Ranking/
├── scripts/
│   ├── team.mjs          # ⭐ Danh sách team, cửa sổ tháng, trọng số quen tay & thưởng giải
│   └── compute.mjs       # Fetch API + tính ELO cửa sổ 6 tháng (Node, không cần package)
├── app/                  # Flutter web (đọc data/leaderboard.json qua HTTP)
│   ├── web/data/leaderboard.json   # Dữ liệu hiển thị (do script ghi)
│   ├── lib/
│   │   ├── main.dart / app.dart    # Khởi động + MaterialApp/theme
│   │   ├── core/                   # Dùng chung: theme (màu), utils, widgets
│   │   └── features/               # Mỗi tính năng 1 thư mục riêng
│   │       ├── leaderboard/        #   Bảng xếp hạng (models/services/pages/widgets)
│   │       ├── match_history/      #   Lịch sử & chi tiết trận
│   │       └── tournament/         #   Giải đấu (models / logic / services / pages / widgets)
│   └── test/                       # Unit test (logic giải đấu, luật lọc trận)
│                                   # + widget test (thẻ ELO, dialog tỉ số, lịch sử trận)
├── .github/workflows/update.yml    # Cron 3 lần/ngày + build + deploy Pages
└── README.md
```

Luồng: `GitHub Actions (cron)` → chạy `compute.mjs` → ghi `leaderboard.json`
(commit lại repo) → build Flutter web → deploy **GitHub Pages**. Web đọc `data/leaderboard.json`.

## Chạy thử ở máy (không cần gì ngoài Node 18+)

```bash
cd AOE_Ranking
node scripts/compute.mjs             # tính ELO cửa sổ 6 tháng -> app/web/data/leaderboard.json

# Xem web tại chỗ (cần Flutter):
cd app && flutter pub get && flutter run -d chrome
```

## Đưa lên mạng (GitHub Actions + Pages)

1. **Tạo repo GitHub** và đẩy toàn bộ thư mục `AOE_Ranking` lên nhánh `main`:
   ```bash
   cd AOE_Ranking
   git init && git add . && git commit -m "init AoE Ranking"
   git branch -M main
   git remote add origin https://github.com/<user>/<repo>.git
   git push -u origin main
   ```
2. Trên GitHub: **Settings → Pages → Build and deployment → Source = GitHub Actions**.
3. Vào tab **Actions**, chọn workflow **"Cập nhật ELO & deploy web" → Run workflow** để chạy
   lần đầu (hoặc đợi tới mốc cron). Sau khi chạy xong, link web ở dạng
   `https://<user>.github.io/<repo>/`.

> Repo **public** thì GitHub Actions miễn phí không giới hạn phút. Repo private cũng có
> 2000 phút/tháng miễn phí — vẫn dư dùng.

### Nếu bạn fork repo này (quan trọng)

Tính năng **Giải đấu** dùng Firebase Realtime Database. `app/lib/firebase_options.dart` và
`FIREBASE_DB_URL` trong `scripts/team.mjs` đang trỏ vào project Firebase của repo gốc — fork
mà không đổi thì bạn sẽ ghi/xoá giải trong cơ sở dữ liệu của người khác. Hãy tạo project
Firebase riêng (bật Realtime Database), thay 2 chỗ trên, và đặt lại rules cho phù hợp.

Lưu ý bảo mật: PIN của giải được lưu dạng văn bản thường và **kiểm tra ở phía trình duyệt**,
nên nó chỉ ngăn thao tác nhầm chứ không phải cơ chế bảo mật. Bảng xếp hạng ELO không dùng
Firebase nên không bị ảnh hưởng.

## Vận hành

- ELO **tự cập nhật** 7:00 / 14:00 / 21:00 hàng ngày. Muốn cập nhật ngay: **Actions → Run workflow**.
- Nút 🔄 trên web để tải lại dữ liệu mới nhất.
- **Đổi thành viên / độ dài cửa sổ / trọng số**: sửa `scripts/team.mjs` (`TEAM`,
  `WINDOW_MONTHS`, `ACTIVITY_WEIGHT`, `TOURNEY_BONUS`) rồi commit & push. Mỗi lần chạy đều
  tính lại toàn bộ nên có hiệu lực ngay.
- **Chạy test trước khi push**: `cd app && flutter analyze && flutter test`
  (CI cũng chạy 2 lệnh này và sẽ chặn deploy nếu hỏng).

## Ghi chú

- Nguồn dữ liệu (đều public, CORS mở):
  - `GET .../statistics/history` — lịch sử trận (`user_uuid`, `game_code=aoe`, `size`, `index`)
  - `GET .../statistics/profile` — tên + avatar hiện tại của thành viên
  - Firebase RTDB REST (`/tournaments.json`) — kết quả giải đấu để cộng điểm thưởng
- ELO **không** lấy từ field `elo_change` của API; script tự tính lại toàn bộ từ các chỉ số
  trong `statistics` nên mọi trận trong cửa sổ đều ảnh hưởng ELO.
- **Điểm phong độ được cân về tâm 0.5 mỗi trận.** Đây là điều kiện để ELO không rò rỉ:
  chuẩn hoá min-max trên chỉ số lệch phải (1 người carry) cho tổng nhỏ hơn kỳ vọng, khiến
  hệ mất điểm mỗi trận và mất nhiều hơn ở trận đông người — trước khi sửa, bảng 4v4 trung
  bình 963 trong khi 1v1 là 998, tức người chơi 4v4 bị dìm ~35 điểm chỉ vì thể loại.
