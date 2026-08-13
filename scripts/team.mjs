// Cấu hình team & luật tính ELO. Sửa ở đây khi thêm/bớt thành viên hoặc đổi tier.

export const GAME_CODE = "aoe";

// Danh sách thành viên team (theo user_uuid). Tên/avatar lấy động từ API.
export const TEAM = [
  "d6c14b8e-d651-49c6-8287-5a069fe7edbc", // Tnos
  "6747bca9-681b-459c-aa5a-309ef5fee99a", // DarkTitan
  "df398dcf-f4e2-44f5-af37-3dfefa8d6c5a", // titi_cuti
  "0b0bb6a4-a2d8-4218-bca0-cd67a242305e", // chimsaudm9_8108
  "a6f69c6c-38cc-4d6a-a2d6-c15bb2792ecc", // thuhoai55_7667
  "1a9ff917-6fe1-484f-8980-d1d4d4aa4778", // 14_northside
  "3db54282-d32b-41f9-950c-cac1cccd8271", // TrumNho
  "ac837498-0e68-4299-a5ce-b8f34a5385a9", // minh_0909
  "65711749-451a-4df6-a140-11d0a2b6e45f", // Spainno3
  "c5dd6537-6818-4309-869d-9bea79193999", // phucyknb
  "7fdee180-f5ef-43e7-be86-3c0e30535010", // EmBe.HY
  "ffe110f9-6f29-429f-9127-4f775cec9546", // ntduc12_3779
  "bbb371ae-d57c-4f9c-ade8-94bae76cab22", // Tada
  "da912471-4373-4d2e-90fb-adb8c7e319bb", // Chucbb
];

// Cửa sổ trượt: chỉ tính ELO các trận trong N THÁNG GẦN NHẤT tính tới thời điểm chạy.
// Mỗi lần cập nhật đều lấy lại đúng N tháng gần nhất (trận cũ hơn sẽ rơi ra khỏi bảng).
export const WINDOW_MONTHS = 6;

// "Độ quen tay": ELO hiển thị cộng thêm ACTIVITY_WEIGHT × √(số trận của bảng đó).
// Trọng số nhỏ: 100 trận → +10, 200 trận → +14 (thang ELO ~750–1200).
export const ACTIVITY_WEIGHT = 1;

// Cộng ELO từ kết quả GIẢI ĐẤU trên web (chỉ giải ĐÃ KẾT THÚC — bấm "Kết thúc giải"):
// thành viên đội vô địch/á quân được cộng vào bảng Tổng và bảng thể loại của giải.
export const TOURNEY_BONUS = { champion: 15, runnerUp: 7 };

// Firebase RTDB chứa dữ liệu giải đấu (đọc công khai qua REST).
export const FIREBASE_DB_URL =
  "https://aoe-ranking-default-rtdb.asia-southeast1.firebasedatabase.app";

// Phân tier từ trên xuống theo ELO giảm dần. Tổng size nên bằng số thành viên.
// Top 1 = 3 người, Top 2 = 2, Top 3 = 2, Top 4 = 3. (Top 5 chưa dùng.)
export const TIERS = [
  { label: "Top 1", size: 3 },
  { label: "Top 2", size: 2 },
  { label: "Top 3", size: 2 },
  { label: "Top 4", size: 3 },
];
