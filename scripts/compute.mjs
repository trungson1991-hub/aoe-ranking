// Tính "Performance ELO" nội bộ team trong cửa sổ trượt N tháng.
// ELO không chỉ dựa vào thắng/thua mà dựa vào phong độ (các chỉ số trong trận).
// Mỗi lần chạy tính lại toàn bộ trong cửa sổ (không dùng checkpoint).
//
// Chạy:  node scripts/compute.mjs
// Ghi ra: app/web/data/leaderboard.json
//
// Không cần cài package nào (dùng fetch có sẵn của Node 18+).

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { TEAM, WINDOW_MONTHS, TIERS, GAME_CODE } from "./team.mjs";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const OUT_FILE = path.join(ROOT, "app", "web", "data", "leaderboard.json");

const BASE =
  "https://game-offline.gplay.vn/game/offline/api/v2.1/statistics/history";
const PROFILE_BASE =
  "https://game-offline.gplay.vn/game/offline/api/v2.1/statistics/profile";
const HEADERS = {
  Accept: "application/json",
  Origin: "https://gplay.vn",
  Referer: "https://gplay.vn/",
};

// ---- Tham số cơ chế ELO ----
const K = 28; // độ nhạy mỗi trận
const ALPHA = 0.5; // trọng số Kết quả (thắng/thua) so với Phong độ (chỉ số)
const MODES = ["1v1", "2v2", "3v3", "4v4"]; // các thể loại tính riêng (trận cân người)

// Điều chỉnh theo TỔNG SỐ TRẬN (trong cửa sổ, theo từng bảng):
//   ELO_hiển_thị = rating × games/(games+CONF_C)  +  ACT_B × √games
//   - Hệ số tin cậy: chơi ít -> ELO co về 0 (tránh mẫu nhỏ vọt top).
//   - Thưởng hoạt động: chơi nhiều -> cộng thêm (giảm dần theo căn bậc hai).
const CONF_C = 10;
const ACT_B = 2;

const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);

// Các chỉ số phong độ: trọng số + hàm "độ tốt" (giá trị càng lớn càng giỏi).
// Tổng trọng số = 1.0. Nhóm: Combat 0.30 / Kinh tế 0.25 / Công nghệ&lên đời 0.25 / Bản đồ&hỗ trợ 0.20
const METRICS = [
  // Combat (0.30)
  { w: 0.15, g: (s) => num(s.kills) }, // giết quân
  { w: 0.1, g: (s) => -num(s.losses) }, // mất quân (ít hơn = tốt)
  { w: 0.05, g: (s) => num(s.razings) }, // phá công trình
  // Kinh tế (0.25)
  { w: 0.1, g: (s) => num(s.gold_collected) }, // đào vàng
  { w: 0.1, g: (s) => num(s.villager_high) }, // nông dân đỉnh
  { w: 0.05, g: (s) => num(s.total_population) }, // tổng dân số
  // Công nghệ & lên đời (0.25)
  { w: 0.1, g: (s) => num(s.technologies) }, // nâng cấp công nghệ
  { w: 0.1, g: (s) => { const t = num(s.bronze_age_upgraded_time); return t > 0 ? -t : NaN; } }, // lên đời nhanh (thời gian ít = tốt; 0 = chưa lên đời → coi như tệ nhất)
  { w: 0.05, g: (s) => (num(s.age) >= 4 ? 1 : 0) }, // đạt đời 4
  // Bản đồ & hỗ trợ (0.20)
  { w: 0.12, g: (s) => num(s.exploration) }, // mở bản đồ
  { w: 0.05, g: (s) => num(s.tribute_given) }, // bơm đồ (cống nạp)
  { w: 0.03, g: (s) => (num(s.total_population) > 0 ? num(s.living_population) / num(s.total_population) : 0) }, // bảo toàn lực lượng
];

// ---- API ----

async function fetchPage(uuid, size, index) {
  const url = `${BASE}?user_uuid=${encodeURIComponent(
    uuid
  )}&game_code=${GAME_CODE}&size=${size}&index=${index}`;
  const res = await fetch(url, { headers: HEADERS });
  if (!res.ok) throw new Error(`GPlay API ${res.status} (user ${uuid}, trang ${index})`);
  const json = await res.json();
  return json?.Data?.list ?? [];
}

// Lấy tên/avatar hiện tại từ hồ sơ user (public, không cần token).
async function fetchProfile(uuid) {
  try {
    const url = `${PROFILE_BASE}?user_uuid=${encodeURIComponent(uuid)}&game_code=${GAME_CODE}`;
    const res = await fetch(url, { headers: HEADERS });
    if (!res.ok) return null;
    const d = (await res.json())?.Data;
    if (!d) return null;
    return { name: d.display_name || "", avatar_url: d.avatar_url || "" };
  } catch {
    return null;
  }
}

async function fetchUserMatches(uuid, fromEpoch) {
  const size = 100;
  const MAX_PAGES = 100;
  const out = [];
  for (let index = 1; index <= MAX_PAGES; index++) {
    const list = await fetchPage(uuid, size, index);
    if (list.length === 0) break;
    let reachedStart = false;
    for (const m of list) {
      if (m.created_time < fromEpoch) reachedStart = true;
      else out.push(m);
    }
    if (reachedStart || list.length < size) break;
  }
  return out;
}

// ---- Lọc trận ----

const teamSet = new Set(TEAM);

// Trận nội bộ: MỌI người chơi (đang có mặt) đều thuộc team.
function isInternal(m) {
  const parts = [...m.red_team_members, ...m.blue_team_members];
  return parts.length > 0 && parts.every((p) => teamSet.has(p.user_uuid));
}

// Trận "ma" (loại): (1) <=1 người hoặc một đội rỗng (Xv0); (2) tổng kills+losses < 10.
function isGhost(m) {
  const red = m.red_team_members.length;
  const blue = m.blue_team_members.length;
  if (red + blue <= 1) return true;
  if (red === 0 || blue === 0) return true;
  let kd = 0;
  for (const s of Object.values(m.statistics || {})) {
    kd += (s.kills ?? 0) + (s.losses ?? 0);
  }
  return kd < 10;
}

// Người chơi THỰC của trận: nếu nhiều người cùng empires_color (cùng 1 slot), chỉ giữ
// người XUẤT HIỆN ĐẦU TIÊN (theo thứ tự red rồi blue); những người sau là "viewer",
// bị loại khỏi mọi tính toán ELO. Màu là duy nhất toàn trận trong AoE.
function realPlayers(m) {
  const order = [
    ...m.red_team_members.map((x) => ({ uuid: x.user_uuid, idx: 0 })),
    ...m.blue_team_members.map((x) => ({ uuid: x.user_uuid, idx: 1 })),
  ];
  const seen = new Set();
  const real = [];
  for (const p of order) {
    const color = m.statistics?.[p.uuid]?.empires_color;
    // Không có màu -> không gộp được, coi mỗi người là 1 slot riêng.
    const key = color === undefined || color === null ? `u:${p.uuid}` : `c:${color}`;
    if (seen.has(key)) continue; // viewer -> bỏ
    seen.add(key);
    real.push(p);
  }
  return real;
}

// Mode theo SỐ NGƯỜI THỰC mỗi đội (từ danh sách đã loại viewer trong perfScores).
function modeKeyFromPlayers(ps) {
  const r = ps.filter((p) => p.idx === 0).length;
  const b = ps.filter((p) => p.idx === 1).length;
  if (r === b && r >= 1 && r <= 4) return `${r}v${b}`;
  return null;
}

// ---- Phong độ ----

// Tính điểm phong độ (0..1) cho mỗi người trong 1 trận, chuẩn hoá min-max TƯƠNG ĐỐI trong trận.
function perfScores(m) {
  const players = realPlayers(m); // chỉ người chơi thực, loại viewer trùng màu
  const stt = m.statistics || {};
  const stats = players.map((p) => stt[p.uuid] || {});

  // Chuẩn hoá từng chỉ số theo min-max giữa những người cùng trận.
  // Giá trị NaN (không hợp lệ, vd chưa lên đời) không tính vào min/max và bị gán 0 (tệ nhất).
  const normed = METRICS.map((mt) => {
    const gs = stats.map((s) => mt.g(s));
    const valid = gs.filter((v) => Number.isFinite(v));
    if (valid.length === 0) return gs.map(() => 0.5);
    const mn = Math.min(...valid);
    const mx = Math.max(...valid);
    return gs.map((v) =>
      !Number.isFinite(v) ? 0 : mx === mn ? 0.5 : (v - mn) / (mx - mn)
    );
  });

  return players.map((p, i) => {
    let perf = 0;
    METRICS.forEach((mt, k) => (perf += mt.w * normed[k][i]));
    return { uuid: p.uuid, idx: p.idx, perf };
  });
}

// ---- Cập nhật ELO tuần tự ----

function emptyBucket() {
  return { rating: 0, games: 0, wins: 0, losses: 0 };
}

function emptyInfo() {
  const info = {};
  for (const u of TEAM) {
    const modes = {};
    for (const k of MODES) modes[k] = emptyBucket();
    info[u] = { name: "", avatar_url: "", last_played: 0, total: emptyBucket(), modes };
  }
  return info;
}

// Thắng/thua lấy từ statistics[uuid].result (1=thắng, 2=thua).
// Lưu ý: KHÔNG dùng victory_team_idx vì field này không đáng tin (luôn = 0).
function isWin(m, uuid) {
  return (m.statistics?.[uuid]?.result ?? 0) === 1;
}

// Cập nhật 1 "bucket" (total hoặc 1 mode) cho tất cả người trong trận.
function applyElo(bucketOf, m, ps) {
  const sums = [0, 0];
  const counts = [0, 0];
  for (const p of ps) {
    sums[p.idx] += bucketOf(p.uuid).rating;
    counts[p.idx] += 1;
  }
  const avg = (i) => (counts[i] ? sums[i] / counts[i] : 0);
  const a0 = avg(0);
  const a1 = avg(1);

  for (const p of ps) {
    const bk = bucketOf(p.uuid);
    const my = p.idx === 0 ? a0 : a1;
    const opp = p.idx === 0 ? a1 : a0;
    const expected = 1 / (1 + Math.pow(10, (opp - my) / 400));
    const win = isWin(m, p.uuid) ? 1 : 0;
    const score = ALPHA * win + (1 - ALPHA) * p.perf;
    bk.rating += K * (score - expected);
    bk.games += 1;
    if (win) bk.wins += 1;
    else bk.losses += 1;
  }
}

function buildLeaderboard(info, meta) {
  const round = (b) => {
    const rel = b.games > 0 ? b.games / (b.games + CONF_C) : 0; // hệ số tin cậy
    const bonus = ACT_B * Math.sqrt(b.games); // thưởng hoạt động
    return {
      elo: Math.round(b.rating * rel + bonus),
      games: b.games,
      wins: b.wins,
      losses: b.losses,
    };
  };
  const members = TEAM.map((u) => {
    const modes = {};
    for (const k of MODES) modes[k] = round(info[u].modes[k]);
    return {
      user_uuid: u,
      name: info[u].name || u.slice(0, 8),
      avatar_url: info[u].avatar_url || "",
      last_played: info[u].last_played,
      total: round(info[u].total),
      modes,
    };
  });
  return { ...meta, tiers: TIERS, members };
}

// ---- Main ----

async function main() {
  const startDate = new Date();
  startDate.setMonth(startDate.getMonth() - WINDOW_MONTHS);
  const START_EPOCH = Math.floor(startDate.getTime() / 1000);

  // Fetch song song: lịch sử trận + hồ sơ (tên/avatar) của mọi thành viên.
  const [lists, profileList] = await Promise.all([
    Promise.all(TEAM.map((uuid) => fetchUserMatches(uuid, START_EPOCH))),
    Promise.all(TEAM.map((uuid) => fetchProfile(uuid))),
  ]);
  const union = new Map();
  for (const list of lists) for (const m of list) union.set(m.game_id, m);
  const profiles = {};
  TEAM.forEach((u, i) => (profiles[u] = profileList[i]));

  const eligible = [...union.values()]
    .filter((m) => isInternal(m) && !isGhost(m))
    .sort((a, b) => a.created_time - b.created_time); // xử lý theo thứ tự thời gian

  const info = emptyInfo();

  // Ngày chơi gần nhất (mọi trận đã fetch, kể cả không tính ELO).
  for (const m of union.values()) {
    for (const x of [...m.red_team_members, ...m.blue_team_members]) {
      const t = info[x.user_uuid];
      if (t && m.created_time > t.last_played) t.last_played = m.created_time;
    }
  }

  for (const m of eligible) {
    // Cập nhật tên/avatar.
    for (const x of [...m.red_team_members, ...m.blue_team_members]) {
      if (info[x.user_uuid]) {
        if (x.name) info[x.user_uuid].name = x.name;
        if (x.avatar_url) info[x.user_uuid].avatar_url = x.avatar_url;
      }
    }
    const ps = perfScores(m);
    applyElo((u) => info[u].total, m, ps); // ELO tổng
    const mk = modeKeyFromPlayers(ps); // theo số người thực (đã loại viewer)
    if (mk) applyElo((u) => info[u].modes[mk], m, ps); // ELO theo thể loại
  }

  // Ưu tiên tên/avatar từ hồ sơ (luôn mới nhất; áp cả cho người 0 trận như Tada).
  for (const u of TEAM) {
    const p = profiles[u];
    if (p) {
      if (p.name) info[u].name = p.name;
      if (p.avatar_url) info[u].avatar_url = p.avatar_url;
    }
  }

  const board = buildLeaderboard(info, {
    updated_at: Math.floor(Date.now() / 1000),
    start_epoch: START_EPOCH,
    window_months: WINDOW_MONTHS,
    total_matches: union.size,
    internal_matches: eligible.length,
  });
  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  fs.writeFileSync(OUT_FILE, JSON.stringify(board, null, 2));

  console.log(
    `Performance ELO — cửa sổ ${WINDOW_MONTHS} tháng: ${eligible.length} trận, ` +
      `từ ${startDate.toISOString().slice(0, 10)}`
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
