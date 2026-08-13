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
import {
  TEAM,
  WINDOW_MONTHS,
  GAME_CODE,
  ACTIVITY_WEIGHT,
  TOURNEY_BONUS,
  TOURNEY_WINDOW_MONTHS,
  FIREBASE_DB_URL,
} from "./team.mjs";

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
// Hệ ELO chuẩn quốc tế: mọi người xuất phát từ RATING_BASE, không bao giờ âm.
// - 10 trận đầu (mỗi bảng) dùng K lớn để "định hạng" nhanh về đúng trình độ;
//   từ trận 11 dùng K nhỏ hơn cho ổn định, ít nhiễu.
// - Dưới PLACEMENT_GAMES trận, client hiển thị nhãn "ELO tạm".
// - ELO hiển thị = rating + độ quen tay (ACTIVITY_WEIGHT·√số trận)
//   + điểm thưởng giải đấu; xem buildLeaderboard.
const RATING_BASE = 1000; // điểm xuất phát (mốc trung bình)
const RATING_FLOOR = 0; // chặn dưới tuyệt đối (thực tế luôn quanh 1000)
const K_PLACEMENT = 40; // độ nhạy 10 trận đầu (định hạng)
const K_STANDARD = 24; // độ nhạy từ trận 11 (ổn định)
const PLACEMENT_GAMES = 10; // số trận định hạng
const ALPHA = 0.5; // trọng số Kết quả (thắng/thua) so với Phong độ (chỉ số)
const MODES = ["1v1", "2v2", "3v3", "4v4"]; // các thể loại tính riêng (trận cân người)

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

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Gọi fetch có retry (API GPlay thỉnh thoảng chập chờn; lỗi 1 request
// không nên làm hỏng cả lần cập nhật của GitHub Action).
async function fetchWithRetry(url, { retries = 3, delayMs = 1500 } = {}) {
  let lastErr;
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, { headers: HEADERS });
      if (res.ok) return res;
      lastErr = new Error(`HTTP ${res.status}`);
    } catch (e) {
      lastErr = e;
    }
    if (attempt < retries) await sleep(delayMs * attempt);
  }
  throw lastErr;
}

async function fetchPage(uuid, size, index) {
  const url = `${BASE}?user_uuid=${encodeURIComponent(
    uuid
  )}&game_code=${GAME_CODE}&size=${size}&index=${index}`;
  let res;
  try {
    res = await fetchWithRetry(url);
  } catch (e) {
    throw new Error(`GPlay API lỗi (user ${uuid}, trang ${index}): ${e.message}`);
  }
  const json = await res.json();
  return json?.Data?.list ?? [];
}

// Lấy tên + bộ trang trí hiện tại từ hồ sơ user (public, không cần token).
// vip_frame / background / effect là đồ trang trí người chơi mua trong game;
// phần lớn người chơi để trống. Lỗi thì trả null (không chặn việc tính ELO).
async function fetchProfile(uuid) {
  try {
    const url = `${PROFILE_BASE}?user_uuid=${encodeURIComponent(uuid)}&game_code=${GAME_CODE}`;
    const res = await fetchWithRetry(url, { retries: 2 });
    const d = (await res.json())?.Data;
    if (!d) return null;
    return {
      name: d.display_name || "",
      avatar_url: d.avatar_url || "",
      vip_frame_url: d.vip_frame_url || "",
      background_url: d.background_url || "",
      effect_url: d.effect_url || "",
    };
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

// Danh sách người chơi 2 đội, phòng khi API thiếu field (tránh sập cả lần chạy).
const membersOf = (m) => [
  ...(m.red_team_members ?? []),
  ...(m.blue_team_members ?? []),
];

// Trận nội bộ: MỌI người chơi (đang có mặt) đều thuộc team.
function isInternal(m) {
  const parts = membersOf(m);
  return parts.length > 0 && parts.every((p) => teamSet.has(p.user_uuid));
}

// Trận "ma" (loại): (1) một đội rỗng (Xv0 — không có đối thủ);
// (2) tổng kills+losses < 10 (không có giao tranh thật).
function isGhost(m) {
  const red = (m.red_team_members ?? []).length;
  const blue = (m.blue_team_members ?? []).length;
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
    ...(m.red_team_members ?? []).map((x) => ({ uuid: x.user_uuid, idx: 0 })),
    ...(m.blue_team_members ?? []).map((x) => ({ uuid: x.user_uuid, idx: 1 })),
  ];
  const seen = new Set();
  const real = [];
  for (const p of order) {
    const color = m.statistics?.[p.uuid]?.empires_color;
    // Màu hợp lệ trong AoE là 1..8. Thiếu màu hoặc 0 = không có dữ liệu ->
    // không gộp được, coi mỗi người là 1 slot riêng (khớp app Flutter).
    const key = !color ? `u:${p.uuid}` : `c:${color}`;
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

  const raw = players.map((_, i) => {
    let perf = 0;
    METRICS.forEach((mt, k) => (perf += mt.w * normed[k][i]));
    return perf;
  });

  // CÂN LẠI VỀ TÂM 0.5 — bắt buộc để ELO không rò rỉ điểm.
  //
  // Elo chỉ bảo toàn khi tổng điểm nhận = tổng kỳ vọng (= n/2). Chuẩn hoá
  // min-max trên các chỉ số lệch phải (1 người carry, phần còn lại dồn cụm)
  // cho tổng NHỎ HƠN n/2, nên mỗi trận cả hệ mất một ít điểm — càng đông
  // người càng mất nhiều. Đo thực tế trước khi sửa: bảng 1v1 trung bình
  // 998 (đúng mốc) nhưng 4v4 chỉ 963, tức người chơi 4v4 bị dìm ~35 điểm
  // chỉ vì thể loại đông người hơn.
  //
  // Dịch cả trận sao cho trung bình phong độ = 0.5: giữ nguyên thứ tự và
  // khoảng cách giữa các người chơi, chỉ đưa tâm về đúng mốc trung lập.
  const mean = raw.reduce((a, b) => a + b, 0) / raw.length;
  return players.map((p, i) => ({
    uuid: p.uuid,
    idx: p.idx,
    perf: raw[i] - mean + 0.5,
  }));
}

// ---- Cập nhật ELO tuần tự ----

function emptyBucket() {
  return { rating: RATING_BASE, games: 0, wins: 0, losses: 0 };
}

function emptyInfo() {
  const info = {};
  for (const u of TEAM) {
    const modes = {};
    for (const k of MODES) modes[k] = emptyBucket();
    info[u] = {
      name: "",
      avatar_url: "",
      vip_frame_url: "",
      background_url: "",
      effect_url: "",
      last_played: 0,
      total: emptyBucket(),
      modes,
    };
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
    // K thích ứng: định hạng nhanh 10 trận đầu, sau đó ổn định.
    const k = bk.games < PLACEMENT_GAMES ? K_PLACEMENT : K_STANDARD;
    bk.rating = Math.max(RATING_FLOOR, bk.rating + k * (score - expected));
    bk.games += 1;
    if (win) bk.wins += 1;
    else bk.losses += 1;
  }
}

// ---- Giải đấu: cộng ELO cho vô địch / á quân các giải ĐÃ KẾT THÚC ----
// Logic bảng điểm / nhánh KO port 1-1 từ app (lib/features/tournament/logic/).

function fxDecided(f, firstTo) {
  return (f.score_a ?? 0) >= firstTo || (f.score_b ?? 0) >= firstTo;
}

function fxWinner(f, firstTo) {
  if ((f.score_a ?? 0) >= firstTo) return f.a_id ?? null;
  if ((f.score_b ?? 0) >= firstTo) return f.b_id ?? null;
  return null;
}

// Bảng xếp hạng vòng tròn: thắng > hiệu số ván > tổng ván thắng.
function tournStandings(t, teamIds, fixtures) {
  const rows = new Map();
  for (const id of teamIds ?? []) {
    // Chỉ xếp hạng đội CÒN tồn tại trong danh sách đội (khớp app): id mồ côi
    // sẽ tạo dòng "ma" 0 trận và có thể chiếm mất suất á quân.
    const team = (t.teams ?? []).find((x) => x?.id === id);
    if (!team) continue;
    rows.set(id, { id, name: team.name ?? "", wins: 0, gameWon: 0, gameLost: 0 });
  }
  for (const f of fixtures ?? []) {
    const a = rows.get(f.a_id);
    const b = rows.get(f.b_id);
    if (!a || !b || !fxDecided(f, t.first_to)) continue;
    a.gameWon += f.score_a ?? 0;
    a.gameLost += f.score_b ?? 0;
    b.gameWon += f.score_b ?? 0;
    b.gameLost += f.score_a ?? 0;
    if (fxWinner(f, t.first_to) === f.a_id) a.wins++;
    else b.wins++;
  }
  // Thứ tự tie-break phải KHỚP app (standings.dart) — nếu khác, script có
  // thể trao điểm cho đội khác với đội web hiển thị là vô địch.
  return [...rows.values()].sort(
    (x, y) =>
      y.wins - x.wins ||
      y.gameWon - y.gameLost - (x.gameWon - x.gameLost) ||
      y.gameWon - x.gameWon ||
      String(x.name).localeCompare(String(y.name))
  );
}

// Suy đội thắng chung kết từ nhánh KO (id dạng ko_r{round}_m{match}).
function koResult(t) {
  const fixtures = t.ko_fixtures ?? [];
  if (!fixtures.length) return null;
  const byId = new Map(fixtures.map((f) => [f.id, f]));
  const roundSize = new Map();
  for (const f of fixtures) {
    const m = /^ko_r(\d+)_m(\d+)$/.exec(f.id ?? "");
    if (m) roundSize.set(+m[1], Math.max(roundSize.get(+m[1]) ?? 0, +m[2] + 1));
  }
  if (!roundSize.size) return null;
  const maxRound = Math.max(...roundSize.keys());
  if (roundSize.get(maxRound) !== 1) return null;
  const winners = new Map();
  let final_ = null;
  for (let r = 0; r <= maxRound; r++) {
    for (let m = 0; m < (roundSize.get(r) ?? 0); m++) {
      const f = byId.get(`ko_r${r}_m${m}`);
      if (!f) continue;
      const aId = r === 0 ? f.a_id ?? null : winners.get(`${r - 1}_${2 * m}`) ?? null;
      const bId = r === 0 ? f.b_id ?? null : winners.get(`${r - 1}_${2 * m + 1}`) ?? null;
      // Ô trống ở VÒNG ĐẦU = bye (đi tiếp luôn). Ở vòng sau nghĩa là trận
      // trước chưa đá xong -> chưa có đội thắng; nếu coi là bye sẽ trao ELO
      // vô địch cho đội chưa đá chung kết.
      let w = null;
      if (aId == null || bId == null) {
        if (r === 0) w = aId ?? bId;
      } else if ((f.score_a ?? 0) >= t.first_to) {
        w = aId;
      } else if ((f.score_b ?? 0) >= t.first_to) {
        w = bId;
      }
      winners.set(`${r}_${m}`, w);
      if (r === maxRound && m === 0) final_ = { aId, bId, w };
    }
  }
  if (!final_?.w) return null;
  const runner = final_.w === final_.aId ? final_.bId : final_.aId;
  return { championId: final_.w, runnerUpId: runner ?? null };
}

// Vô địch + á quân của 1 giải (null nếu chưa xác định được).
function tournamentPodium(t) {
  if (t.structure === "groups_knockout") return koResult(t);
  // round_robin: chỉ trao giải khi MỌI trận đã đá xong — giống điều kiện
  // hiện banner vô địch trên web. Trước đây chỉ cần 1 trận có kết quả là
  // đã trao +15/+7, kể cả cho đội chưa đá trận nào.
  const g = (t.groups ?? [])[0];
  if (!g) return null;
  const fixtures = t.group_fixtures ?? [];
  if (!fixtures.length || !fixtures.every((f) => fxDecided(f, t.first_to))) {
    return null;
  }
  const st = tournStandings(t, g.team_ids, fixtures);
  if (!st.length) return null;
  return { championId: st[0]?.id ?? null, runnerUpId: st[1]?.id ?? null };
}

// Điểm cộng theo uuid: { total, modes: { '1v1': n, ... } }.
// Chỉ tính giải ĐÃ KẾT THÚC trong cửa sổ TOURNEY_WINDOW_MONTHS gần nhất.
// Lỗi mạng/Firebase -> trả rỗng, KHÔNG làm hỏng lần cập nhật.
async function fetchTournamentBonuses(sinceEpoch) {
  const bonuses = new Map();
  let finished = 0;
  let expired = 0;
  try {
    const res = await fetchWithRetry(`${FIREBASE_DB_URL}/tournaments.json`, {
      retries: 2,
    });
    const data = await res.json();
    for (const [id, t] of Object.entries(data ?? {})) {
      // Bọc từng giải: dữ liệu 1 giải hỏng không được làm mất điểm thưởng
      // của tất cả các giải còn lại.
      try {
        if ((t?.status ?? "active") !== "finished") continue;
        // Mốc kết thúc; giải kết thúc trước khi có field này thì tạm dùng
        // ngày tạo (ước lượng an toàn, không bao giờ trễ hơn thực tế).
        const endedAt = Number(t.finished_at) || Number(t.created_at) || 0;
        if (endedAt && endedAt < sinceEpoch) {
          expired++;
          continue;
        }
        const podium = tournamentPodium(t);
        if (!podium) continue;
        finished++;
        const format = t.format || "1v1"; // khớp mặc định của app
        const award = (teamId, points) => {
          const team = (t.teams ?? []).find((x) => x?.id === teamId);
          for (const uuid of team?.member_uuids ?? []) {
            const b = bonuses.get(uuid) ?? { total: 0, modes: {} };
            b.total += points;
            b.modes[format] = (b.modes[format] ?? 0) + points;
            bonuses.set(uuid, b);
          }
        };
        if (podium.championId) award(podium.championId, TOURNEY_BONUS.champion);
        if (podium.runnerUpId) award(podium.runnerUpId, TOURNEY_BONUS.runnerUp);
      } catch (e) {
        console.log(`Bỏ qua giải ${id} (dữ liệu không hợp lệ): ${e.message}`);
      }
    }
  } catch (e) {
    console.log(`Bỏ qua điểm giải đấu (không đọc được Firebase): ${e.message}`);
  }
  return { bonuses, finished, expired };
}

function buildLeaderboard(info, meta, tournBonuses) {
  // ELO hiển thị = rating + độ quen tay (√số trận, trọng số nhỏ)
  //              + điểm thưởng giải đấu (nếu có).
  const round = (b, extra = 0) => ({
    elo: Math.round(b.rating + ACTIVITY_WEIGHT * Math.sqrt(b.games) + extra),
    games: b.games,
    wins: b.wins,
    losses: b.losses,
  });
  const members = TEAM.map((u) => {
    const bonus = tournBonuses?.get(u);
    const modes = {};
    for (const k of MODES) {
      modes[k] = round(info[u].modes[k], bonus?.modes[k] ?? 0);
    }
    return {
      user_uuid: u,
      name: info[u].name || u.slice(0, 8),
      avatar_url: info[u].avatar_url || "",
      // Đồ trang trí (phần lớn người chơi để trống) — chỉ ghi khi có,
      // để file dữ liệu không phình lên bằng các chuỗi rỗng.
      ...(info[u].vip_frame_url && { vip_frame_url: info[u].vip_frame_url }),
      ...(info[u].background_url && { background_url: info[u].background_url }),
      ...(info[u].effect_url && { effect_url: info[u].effect_url }),
      last_played: info[u].last_played,
      total: round(info[u].total, bonus?.total ?? 0),
      modes,
    };
  });
  return { ...meta, members };
}

// ---- Main ----

// Lùi `months` tháng từ `from`. Đặt ngày về 1 trước khi lùi tháng để tránh
// tràn ngày (31/8 lùi 6 tháng thành 3/3 thay vì 28/2), khiến cửa sổ nhảy
// bất thường vào các ngày cuối tháng.
function monthsAgo(from, months) {
  const d = new Date(from);
  d.setDate(1);
  d.setMonth(d.getMonth() - months);
  d.setDate(
    Math.min(
      from.getDate(),
      new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
    )
  );
  return d;
}

async function main() {
  const now = new Date();
  const startDate = monthsAgo(now, WINDOW_MONTHS);
  const START_EPOCH = Math.floor(startDate.getTime() / 1000);
  // Cửa sổ riêng (dài hơn) cho điểm thưởng giải đấu.
  const TOURNEY_START = Math.floor(
    monthsAgo(now, TOURNEY_WINDOW_MONTHS).getTime() / 1000
  );

  // Fetch song song: lịch sử trận + hồ sơ (tên/avatar) + điểm thưởng giải đấu.
  const [lists, profileList, tourney] = await Promise.all([
    Promise.all(TEAM.map((uuid) => fetchUserMatches(uuid, START_EPOCH))),
    Promise.all(TEAM.map((uuid) => fetchProfile(uuid))),
    fetchTournamentBonuses(TOURNEY_START),
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
    for (const x of membersOf(m)) {
      const t = info[x.user_uuid];
      if (t && m.created_time > t.last_played) t.last_played = m.created_time;
    }
  }

  let skipped = 0;
  for (const m of eligible) {
    // Cập nhật tên/avatar.
    for (const x of membersOf(m)) {
      if (info[x.user_uuid]) {
        if (x.name) info[x.user_uuid].name = x.name;
        if (x.avatar_url) info[x.user_uuid].avatar_url = x.avatar_url;
      }
    }
    const ps = perfScores(m);
    // Sau khi loại viewer mà một đội không còn ai -> không có đối thủ để so
    // kỳ vọng, bỏ qua trận (nếu tính, ELO trung bình đội rỗng = 0 sẽ làm
    // kỳ vọng lệch hẳn về 1 và trừ điểm oan).
    if (!ps.some((p) => p.idx === 0) || !ps.some((p) => p.idx === 1)) {
      skipped++;
      continue;
    }
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
      info[u].vip_frame_url = p.vip_frame_url || "";
      info[u].background_url = p.background_url || "";
      info[u].effect_url = p.effect_url || "";
    }
  }

  const board = buildLeaderboard(
    info,
    {
      updated_at: Math.floor(Date.now() / 1000),
      start_epoch: START_EPOCH,
      window_months: WINDOW_MONTHS,
      total_matches: union.size,
      // Chỉ đếm trận THỰC SỰ vào ELO (trừ trận bị bỏ vì một đội rỗng
      // sau khi loại viewer) — con số này hiện trên web.
      internal_matches: eligible.length - skipped,
    },
    tourney.bonuses
  );
  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  fs.writeFileSync(OUT_FILE, JSON.stringify(board, null, 2));

  console.log(
    `Performance ELO — cửa sổ ${WINDOW_MONTHS} tháng: ${eligible.length} trận, ` +
      `từ ${startDate.toISOString().slice(0, 10)}; ` +
      `${tourney.finished} giải được cộng điểm` +
      (tourney.expired
        ? ` (${tourney.expired} giải quá ${TOURNEY_WINDOW_MONTHS} tháng, không tính)`
        : "")
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
