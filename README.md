# AoE Ranking — Bảng xếp hạng ELO nội bộ team

Web tính điểm ELO riêng cho các thành viên team dựa trên API lịch sử đấu GPlay.
**Miễn phí hoàn toàn, không cần thẻ tín dụng** (dùng GitHub Actions + GitHub Pages).

## Luật tính ELO

- ELO mỗi thành viên **bắt đầu từ 0**, chỉ tính các trận trong **6 tháng gần nhất** (cửa sổ
  trượt, cấu hình `WINDOW_MONTHS` trong `scripts/team.mjs`). Mỗi lần cập nhật tính lại toàn bộ
  cửa sổ này — trận cũ hơn 6 tháng tự rơi ra.
- Chỉ tính trận **nội bộ**: TẤT CẢ người chơi của cả 2 đội đều là thành viên team.
- Mỗi trận nội bộ cộng `elo_change` (API GPlay trả sẵn) vào ELO từng người. **Cho phép âm.**
- Xếp hạng theo ELO giảm dần, chia tier: **Top 1 = 3 người, Top 2 = 2, Top 3 = 2, Top 4 = 3**.
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
