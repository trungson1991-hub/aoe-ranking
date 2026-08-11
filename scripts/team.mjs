// Cấu hình team & luật tính ELO. Sửa ở đây khi thêm/bớt thành viên hoặc đổi tier.

export const GAME_CODE = "aoe";

// Danh sách thành viên team (theo user_uuid). Tên/avatar lấy động từ API.
export const TEAM = [
  "d6c14b8e-d651-49c6-8287-5a069fe7edbc",
  "6747bca9-681b-459c-aa5a-309ef5fee99a",
  "df398dcf-f4e2-44f5-af37-3dfefa8d6c5a",
  "0b0bb6a4-a2d8-4218-bca0-cd67a242305e",
  "a6f69c6c-38cc-4d6a-a2d6-c15bb2792ecc",
  "1a9ff917-6fe1-484f-8980-d1d4d4aa4778",
  "3db54282-d32b-41f9-950c-cac1cccd8271",
  "ac837498-0e68-4299-a5ce-b8f34a5385a9",
  "65711749-451a-4df6-a140-11d0a2b6e45f",
  "c5dd6537-6818-4309-869d-9bea79193999",
];

// ELO bắt đầu cộng dồn từ 00:00 ngày 01/06/2026 (giờ VN, UTC+7).
export const START_EPOCH = Math.floor(
  new Date("2026-06-01T00:00:00+07:00").getTime() / 1000
);

// Phân tier từ trên xuống theo ELO giảm dần. Tổng size nên bằng số thành viên.
// Top 1 = 3 người, Top 2 = 2, Top 3 = 2, Top 4 = 3. (Top 5 chưa dùng.)
export const TIERS = [
  { label: "Top 1", size: 3 },
  { label: "Top 2", size: 2 },
  { label: "Top 3", size: 2 },
  { label: "Top 4", size: 3 },
];
