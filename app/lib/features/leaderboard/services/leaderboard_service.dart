import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../match_history/models/match_record.dart';
import '../models/leaderboard.dart';

// URL web đã deploy — dùng cho app mobile (nơi không có Uri.base như trên web).
const String kDeployedBaseUrl = 'https://trungson1991-hub.github.io/aoe-ranking/';

class LeaderboardService {
  const LeaderboardService();

  // Đọc file tĩnh data/leaderboard.json.
  //  - Web: lấy tương đối theo origin hiện tại.
  //  - Mobile (Android/iOS): lấy tuyệt đối từ site đã deploy.
  // Thêm tham số chống cache để luôn lấy bản mới nhất do GitHub Action ghi.
  Future<Leaderboard> fetch() async {
    final base = kIsWeb
        ? Uri.base.resolve('data/leaderboard.json')
        : Uri.parse('${kDeployedBaseUrl}data/leaderboard.json');
    final uri = base.replace(queryParameters: {
      ...base.queryParameters,
      '_': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} khi tải leaderboard.json');
    }
    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return Leaderboard.fromMap(map);
  }

  // Lịch sử trận của 1 user, lấy trực tiếp từ API GPlay (public, CORS mở).
  // Chỉ giữ trận nội bộ hợp lệ có created_time >= sinceEpoch (cùng luật với compute.mjs).
  Future<List<MatchRecord>> fetchUserHistory(
    String uuid, {
    required int sinceEpoch,
    required Set<String> teamUuids,
  }) async {
    const base =
        'https://game-offline.gplay.vn/game/offline/api/v2.1/statistics/history';
    const pageSize = 100;
    const maxPages = 12; // đủ cho ~1200 trận / 6 tháng
    final out = <MatchRecord>[];
    for (var index = 1; index <= maxPages; index++) {
      final uri = Uri.parse(
          '$base?user_uuid=$uuid&game_code=aoe&size=$pageSize&index=$index');
      final res = await http.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) break;
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final list = (body['Data']?['list'] as List?) ?? const [];
      if (list.isEmpty) break;
      var reachedStart = false;
      for (final e in list) {
        final j = Map<String, dynamic>.from(e as Map);
        final rec = MatchRecord.fromApi(j, uuid, teamUuids);
        if (rec.createdTime < sinceEpoch) {
          reachedStart = true;
          continue;
        }
        if (rec.internal && !rec.ghost) out.add(rec);
      }
      if (reachedStart || list.length < pageSize) break;
    }
    out.sort((a, b) => b.createdTime - a.createdTime); // mới nhất trước
    return out;
  }
}
