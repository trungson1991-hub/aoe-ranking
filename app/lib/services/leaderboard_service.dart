import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/leaderboard.dart';

class LeaderboardService {
  const LeaderboardService();

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
