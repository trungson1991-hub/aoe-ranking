// Tính ELO nội bộ team theo cơ chế TĂNG DẦN (incremental) có lưu checkpoint.
//
// Chạy:  node scripts/compute.mjs            -> cập nhật tăng dần từ checkpoint
//        node scripts/compute.mjs --rebuild  -> tính lại từ đầu (bỏ checkpoint)
//        REBUILD=1 node scripts/compute.mjs   -> tương tự --rebuild
//
// Ghi ra:
//   scripts/state.json               -> checkpoint (cursor + ELO luỹ kế) để lần sau chạy tiếp
//   app/web/data/leaderboard.json    -> dữ liệu cho web hiển thị
//
// Không cần cài package nào (dùng fetch có sẵn của Node 18+).

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { TEAM, START_EPOCH, TIERS, GAME_CODE } from "./team.mjs";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const STATE_FILE = path.join(ROOT, "scripts", "state.json");
const OUT_FILE = path.join(ROOT, "app", "web", "data", "leaderboard.json");

const REBUILD =
  process.argv.includes("--rebuild") || process.env.REBUILD === "1";

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

function isInternal(m) {
  const parts = [...m.red_team_members, ...m.blue_team_members];
  return parts.length > 0 && parts.every((p) => teamSet.has(p.user_uuid));
}

function emptyTotals() {
  const t = {};
  for (const u of TEAM)
    t[u] = { elo: 0, games: 0, wins: 0, losses: 0, name: "", avatar_url: "" };
  return t;
}

function normalizeTotals(src) {
  const t = emptyTotals();
  if (src) for (const u of TEAM) if (src[u]) t[u] = { ...t[u], ...src[u] };
  return t;
}

function accumulate(totals, internalMatches) {
  for (const m of internalMatches) {
    for (const [members, idx] of [
      [m.red_team_members, 0],
      [m.blue_team_members, 1],
    ]) {
      for (const x of members) {
        const t = totals[x.user_uuid];
        if (!t) continue;
        t.elo += x.elo_change ?? 0;
        t.games += 1;
        if (m.victory_team_idx === idx) t.wins += 1;
        else t.losses += 1;
        if (x.name) t.name = x.name;
        if (x.avatar_url) t.avatar_url = x.avatar_url;
      }
    }
  }
}

function buildLeaderboard(totals, meta) {
  const ranked = [...TEAM].sort((a, b) => {
    const d = totals[b].elo - totals[a].elo;
    return d !== 0 ? d : totals[b].wins - totals[a].wins;
  });
  const build = (u, rank, tier) => ({
    user_uuid: u,
    name: totals[u].name || u.slice(0, 8),
    avatar_url: totals[u].avatar_url || "",
    elo: totals[u].elo,
    games: totals[u].games,
    wins: totals[u].wins,
    losses: totals[u].losses,
    rank,
    tier,
  });
  const members = [];
  let i = 0;
  for (const t of TIERS)
    for (let k = 0; k < t.size && i < ranked.length; k++, i++)
      members.push(build(ranked[i], i + 1, t.label));
  for (; i < ranked.length; i++) members.push(build(ranked[i], i + 1, ""));
  return { ...meta, members };
}

const CONFIG_KEY = JSON.stringify({
  team: [...TEAM].sort(),
  start: START_EPOCH,
  tiers: TIERS,
});

// ---- Main ----

async function main() {
  let prev = null;
  if (!REBUILD && fs.existsSync(STATE_FILE)) {
    try {
      prev = JSON.parse(fs.readFileSync(STATE_FILE, "utf8"));
    } catch {
      prev = null;
    }
  }

  const doRebuild = REBUILD || !prev || prev.config_key !== CONFIG_KEY;

  const fromEpoch = doRebuild ? START_EPOCH : prev.cursor_epoch;
  const prevBoundary = new Set(doRebuild ? [] : prev.boundary_ids ?? []);
  const totals = doRebuild ? emptyTotals() : normalizeTotals(prev.totals);
  let internalCount = doRebuild ? 0 : prev.internal_matches ?? 0;
  let totalSeen = doRebuild ? 0 : prev.total_seen ?? 0;

  const fullUnion = new Map();
  for (const uuid of TEAM) {
    const list = await fetchUserMatches(uuid, fromEpoch);
    for (const m of list) fullUnion.set(m.game_id, m);
  }

  let cursor = doRebuild ? START_EPOCH : prev.cursor_epoch;
  let boundary = doRebuild ? [] : prev.boundary_ids ?? [];
  if (fullUnion.size > 0) {
    cursor = Math.max(...[...fullUnion.values()].map((m) => m.created_time));
    boundary = [...fullUnion.values()]
      .filter((m) => m.created_time === cursor)
      .map((m) => m.game_id);
  }

  const newMatches = [...fullUnion.values()].filter(
    (m) => !prevBoundary.has(m.game_id)
  );
  const internalNew = newMatches
    .filter(isInternal)
    .sort((a, b) => a.created_time - b.created_time);

  accumulate(totals, internalNew);
  internalCount += internalNew.length;
  totalSeen += newMatches.length;

  const nowEpoch = Math.floor(Date.now() / 1000);

  const state = {
    config_key: CONFIG_KEY,
    cursor_epoch: cursor,
    boundary_ids: boundary,
    totals,
    internal_matches: internalCount,
    total_seen: totalSeen,
  };
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));

  const board = buildLeaderboard(totals, {
    updated_at: nowEpoch,
    start_epoch: START_EPOCH,
    total_matches: totalSeen,
    internal_matches: internalCount,
  });
  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  fs.writeFileSync(OUT_FILE, JSON.stringify(board, null, 2));

  console.log(
    `${doRebuild ? "REBUILD" : "INCREMENT"}: +${internalNew.length} trận nội bộ mới ` +
      `(tổng ${internalCount}), cursor=${cursor}`
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
