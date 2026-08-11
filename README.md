# AoE Ranking — Bảng xếp hạng ELO nội bộ team

Web tính điểm ELO riêng cho các thành viên team dựa trên API lịch sử đấu GPlay.
**Miễn phí hoàn toàn, không cần thẻ tín dụng** (dùng GitHub Actions + GitHub Pages).

## Luật tính ELO

- ELO mỗi thành viên **bắt đầu từ 0**, cộng dồn từ **00:00 ngày 01/06/2026** (giờ VN).
- Chỉ tính trận **nội bộ**: TẤT CẢ người chơi của cả 2 đội đều là thành viên team.
- Mỗi trận nội bộ cộng `elo_change` (API GPlay trả sẵn) vào ELO từng người. **Cho phép âm.**
- Xếp hạng theo ELO giảm dần, chia tier: **Top 1 = 3 người, Top 2 = 2, Top 3 = 2, Top 4 = 3**.
- **Cập nhật tăng dần (incremental)**: lưu checkpoint `scripts/state.json`; mỗi lần chạy chỉ
  fetch trận mới hơn mốc rồi cộng tiếp — không tính lại từ đầu.
- Tự chạy **7:00 / 14:00 / 21:00 hàng ngày** (giờ VN) bằng GitHub Actions cron.

## Kiến trúc

```
AOE_Ranking/
├── scripts/
│   ├── team.mjs          # ⭐ Danh sách team, mốc bắt đầu, cấu hình tier
│   ├── compute.mjs       # Fetch API + tính ELO incremental (Node, không cần package)
│   └── state.json        # Checkpoint (do script/Action ghi)
├── app/                  # Flutter web (đọc data/leaderboard.json qua HTTP)
│   ├── web/data/leaderboard.json   # Dữ liệu hiển thị (do script ghi)
│   └── lib/{main,models/,services/,ui/}.dart
├── .github/workflows/update.yml    # Cron 3 lần/ngày + build + deploy Pages
└── README.md
```

Luồng: `GitHub Actions (cron)` → chạy `compute.mjs` → ghi `leaderboard.json` + `state.json`
(commit lại repo) → build Flutter web → deploy **GitHub Pages**. Web đọc `data/leaderboard.json`.

## Chạy thử ở máy (không cần gì ngoài Node 18+)

```bash
cd AOE_Ranking
node scripts/compute.mjs --rebuild   # tính từ đầu, tạo state.json + leaderboard.json
node scripts/compute.mjs             # các lần sau: cập nhật tăng dần

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
- **Đổi thành viên/tier/mốc bắt đầu**: sửa `scripts/team.mjs`. `config_key` đổi → lần chạy kế
  **tự rebuild** (tính lại từ đầu). Không cần làm gì thêm.
- **Ép tính lại từ đầu**: chạy `node scripts/compute.mjs --rebuild` rồi commit, hoặc xoá
  `scripts/state.json` trước khi chạy Action.

## Ghi chú

- API GPlay dùng: `GET https://game-offline.gplay.vn/game/offline/api/v2.1/statistics/history`
  với `user_uuid`, `game_code=aoe`, `size`, `index` (public, CORS mở).
- **Giới hạn incremental**: nếu API sửa/xoá `elo_change` của trận cũ, hoặc có trận cũ xuất hiện
  trễ hơn mốc đã lưu, incremental không thấy → chạy `--rebuild` khi cần chuẩn hoá lại.
