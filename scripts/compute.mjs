// Tính ELO nội bộ team trong CỬA SỔ TRƯỢT N tháng gần nhất.
// Mỗi lần chạy đều tính lại toàn bộ trong phạm vi N tháng (không dùng checkpoint,
// vì cửa sổ trượt nên trận cũ phải rơi ra khỏi bảng mỗi lần).
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
const HEADERS = {
  Accept: "application/json",
  Origin: "https://gplay.vn",
  Referer: "https://gplay.vn/",
};

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

// Lấy mọi trận có created_time >= fromEpoch (API trả mới -> cũ nên dừng sớm).
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

// ---- Tính ELO ----

const teamSet = new Set(TEAM);

// Trận nội bộ hợp lệ:
//   - CẢ HAI đội đều có người (loại các bản ghi 1 đội rỗng như 1v0/2v0 — không có đối thủ),
//   - MỌI người chơi của cả 2 đội đều thuộc team (chỉ cần 1 người ngoài team là loại).
function isInternal(m) {
  const red = m.red_team_members;
  const blue = m.blue_team_members;
  if (red.length === 0 || blue.length === 0) return false;
  return [...red, ...blue].every((p) => teamSet.has(p.user_uuid));
}

// Các thể loại tính ELO riêng (chỉ trận cân người). Trận lệch (vd 3v4) chỉ vào ELO tổng.
const MODES = ["1v1", "2v2", "3v3", "4v4"];

function modeKey(m) {
  const r = m.red_team_members.length;
  const b = m.blue_team_members.length;
  if (r === b && r >= 1 && r <= 4) return `${r}v${b}`;
  return null;
}

function emptyStat() {
  return { elo: 0, games: 0, wins: 0, losses: 0 };
}

function emptyTotals() {
  const t = {};
  for (const u of TEAM) {
    const modes = {};
    for (const k of MODES) modes[k] = emptyStat();
    t[u] = { name: "", avatar_url: "", total: emptyStat(), modes };
  }
  return t;
}

function accumulate(totals, internalMatches) {
  for (const m of internalMatches) {
    const mk = modeKey(m);
    for (const [members, idx] of [
      [m.red_team_members, 0],
      [m.blue_team_members, 1],
    ]) {
      for (const x of members) {
        const t = totals[x.user_uuid];
        if (!t) continue;
        const delta = x.elo_change ?? 0;
        const win = m.victory_team_idx === idx;
        const apply = (s) => {
          s.elo += delta;
          s.games += 1;
          if (win) s.wins += 1;
          else s.losses += 1;
        };
        apply(t.total); // ELO tổng: mọi trận nội bộ
        if (mk) apply(t.modes[mk]); // ELO theo thể loại: chỉ trận cân người
        if (x.name) t.name = x.name;
        if (x.avatar_url) t.avatar_url = x.avatar_url;
      }
    }
  }
}

// Xuất dữ liệu thô theo từng người (tổng + từng mode). Việc xếp hạng & chia tier
// do web tự tính theo chế độ đang chọn (không cần tải lại khi đổi mode).
function buildLeaderboard(totals, meta) {
  const members = TEAM.map((u) => ({
    user_uuid: u,
    name: totals[u].name || u.slice(0, 8),
    avatar_url: totals[u].avatar_url || "",
    total: totals[u].total,
    modes: totals[u].modes,
  }));
  return { ...meta, tiers: TIERS, members };
}

// ---- Main ----

async function main() {
  // Mốc bắt đầu = hiện tại lùi N tháng.
  const startDate = new Date();
  startDate.setMonth(startDate.getMonth() - WINDOW_MONTHS);
  const START_EPOCH = Math.floor(startDate.getTime() / 1000);

  // Fetch toàn bộ trận trong cửa sổ của mọi thành viên, gộp theo game_id.
  const union = new Map();
  for (const uuid of TEAM) {
    const list = await fetchUserMatches(uuid, START_EPOCH);
    for (const m of list) union.set(m.game_id, m);
  }

  const internal = [...union.values()]
    .filter(isInternal)
    .sort((a, b) => a.created_time - b.created_time);

  const totals = emptyTotals();
  accumulate(totals, internal);

  const board = buildLeaderboard(totals, {
    updated_at: Math.floor(Date.now() / 1000),
    start_epoch: START_EPOCH,
    window_months: WINDOW_MONTHS,
    total_matches: union.size,
    internal_matches: internal.length,
  });
  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  fs.writeFileSync(OUT_FILE, JSON.stringify(board, null, 2));

  console.log(
    `Cửa sổ ${WINDOW_MONTHS} tháng: ${internal.length} trận nội bộ / ${union.size} trận, ` +
      `từ ${startDate.toISOString().slice(0, 10)}`
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
