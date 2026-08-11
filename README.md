# AoE Ranking — Bảng xếp hạng ELO nội bộ team

Web tính điểm ELO riêng cho các thành viên team dựa trên API lịch sử đấu GPlay.
**Miễn phí hoàn toàn, không cần thẻ tín dụng** (dùng GitHub Actions + GitHub Pages).

## Luật tính ELO

- ELO mỗi thành viên **bắt đầu từ 0**, chỉ tính các trận trong **6 tháng gần nhất** (cửa sổ
  trượt, cấu hình `WINDOW_MONTHS` trong `scripts/team.mjs`). Mỗi lần cập nhật tính lại toàn bộ
  cửa sổ này — trận cũ hơn 6 tháng tự rơi ra.
- Chỉ tính trận **nội bộ**: TẤT CẢ người chơi của cả 2 đội đều là thành viên team.
- Loại **trận "ma"**: (1) chỉ có 1 người chơi hoặc một đội rỗng (Xv0 — không có đối thủ), hoặc
  (2) tổng `kills + losses` (giết + mất quân) của tất cả người chơi `< 10` (không có giao tranh thật).
- **Trùng màu (`empires_color`)**: nếu nhiều người cùng 1 màu/slot, chỉ **người đầu tiên** (theo thứ tự
  danh sách) được tính ELO; những người sau là **viewer**, không tác động (không tính trận/thắng/thua).
  Số người thực mỗi đội (sau khi bỏ viewer) cũng dùng để xác định thể loại 1v1/2v2/3v3/4v4.
- **Performance ELO** (không chỉ thắng/thua): mỗi trận, từng chỉ số (giết/mất quân, phá công trình,
  đào vàng, dân số, công nghệ, tốc độ lên đời, mở bản đồ, bơm đồ...) được chuẩn hoá tương đối giữa
  những người cùng trận thành `perf ∈ [0,1]`. Điểm nhận `S = 0.5·(thắng?1:0) + 0.5·perf`,
  cập nhật `Δ = 28·(S − E)` với `E` là kỳ vọng theo ELO trung bình 2 đội. Bắt đầu 0, **cho phép âm**.
  Thắng/thua lấy từ `statistics.result` (KHÔNG dùng `victory_team_idx` — field này luôn = 0).
- Điều chỉnh theo **tổng số trận** (mỗi bảng): `ELO = rating × games/(games+10) + 2·√games`
  — chơi ít thì ELO co về 0 (tránh mẫu nhỏ vọt top), chơi nhiều được cộng thưởng nhẹ.
- Xếp hạng theo ELO giảm dần (hạng 1, 2, 3...).
- Ngoài ELO **Tổng**, còn tính ELO **riêng cho từng thể loại 1v1 / 2v2 / 3v3 / 4v4** (chỉ trận
  cân người; trận lệch như 3v4 chỉ tính vào Tổng). Web có nút chọn chế độ để xem từng bảng.
- Tự chạy **7:00 / 14:00 / 21:00 hàng ngày** (giờ VN) bằng GitHub Actions cron.

## Kiến trúc

```
AOE_Ranking/
├── scripts/
│   ├── team.mjs          # ⭐ Danh sách team, cửa sổ tháng (WINDOW_MONTHS), cấu hình tier
│   └── compute.mjs       # Fetch API + tính ELO cửa sổ 6 tháng (Node, không cần package)
├── app/                  # Flutter web (đọc data/leaderboard.json qua HTTP)
│   ├── web/data/leaderboard.json   # Dữ liệu hiển thị (do script ghi)
│   └── lib/{main,models/,services/,ui/}.dart
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

## Vận hành

- ELO **tự cập nhật** 7:00 / 14:00 / 21:00 hàng ngày. Muốn cập nhật ngay: **Actions → Run workflow**.
- Nút 🔄 trên web để tải lại dữ liệu mới nhất.
- **Đổi thành viên / tier / độ dài cửa sổ**: sửa `scripts/team.mjs` (mảng `TEAM`, `TIERS`,
  hằng `WINDOW_MONTHS`) rồi commit & push. Mỗi lần chạy đều tính lại toàn bộ nên có hiệu lực ngay.

## Ghi chú

- API GPlay dùng: `GET https://game-offline.gplay.vn/game/offline/api/v2.1/statistics/history`
  với `user_uuid`, `game_code=aoe`, `size`, `index` (public, CORS mở).
- Các trận cũ (trước khi GPlay bật hệ elo) có `elo_change = 0`: vẫn được tính vào số trận /
  thắng-thua nhưng không làm đổi ELO.
