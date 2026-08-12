import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/leaderboard.dart';
import '../models/match_record.dart';

class LeaderboardService {
  const LeaderboardService();

  // Lịch sử trận của 1 user, lấy trực tiếp từ API GPlay (public, CORS mở).
  // Chỉ giữ các trận có created_time >= sinceEpoch (cửa sổ 6 tháng).
  Future<List<MatchRecord>> fetchUserHistory(
    String uuid, {
    required int sinceEpoch,
  }) async {
    const base =
        'https://game-offline.gplay.vn/game/offline/api/v2.1/statistics/history';
    final out = <MatchRecord>[];
    for (var index = 1; index <= 8; index++) {
      final uri = Uri.parse('$base?user_uuid=$uuid&game_code=aoe&size=100&index=$index');
      final res = await http.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) break;
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final list = (body['Data']?['list'] as List?) ?? const [];
      if (list.isEmpty) break;
      var reachedStart = false;
      for (final e in list) {
        final j = Map<String, dynamic>.from(e as Map);
        final rec = MatchRecord.fromApi(j, uuid);
        if (rec.createdTime < sinceEpoch) {
          reachedStart = true;
          continue;
        }
        out.add(rec);
      }
      if (reachedStart || list.length < 100) break;
    }
    out.sort((a, b) => b.createdTime - a.createdTime); // mới nhất trước
    return out;
  }

  // Đọc file tĩnh data/leaderboard.json (nằm cạnh web build, cùng origin).
  // Thêm tham số chống cache để luôn lấy bản mới nhất do GitHub Action ghi.
  Future<Leaderboard?> fetch() async {
    final base = Uri.base.resolve('data/leaderboard.json');
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
}
