import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
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

  // Lịch sử trận của 1 user, đọc từ KHO TRẬN trên Firebase (`history/<uuid>`)
  // do scripts/compute.mjs ghi mỗi lần chạy. App không gọi thẳng GPlay nữa.
  //
  // Đánh đổi đã biết: lịch sử chỉ mới bằng lần chạy CI gần nhất (6 lần/ngày),
  // nên trận vừa đánh xong có thể chưa thấy ngay.
  //
  // Vẫn lọc y hệt compute.mjs (nội bộ / không phải trận ma / người xem phải là
  // người chơi thực) để số trận ở đây khớp số trận trên bảng xếp hạng.
  Future<List<MatchRecord>> fetchUserHistory(
    String uuid, {
    required int sinceEpoch,
    required Set<String> teamUuids,
  }) async {
    final DataSnapshot snap;
    try {
      // Chỉ lấy phần trong cửa sổ: kho giữ trận vĩnh viễn nên tải cả node sẽ
      // phình mãi theo năm tháng. Cần `.indexOn: ["created_time"]` trong rules;
      // thiếu index thì Firebase vẫn trả đúng, chỉ chậm hơn và ghi cảnh báo.
      snap = await FirebaseDatabase.instance
          .ref('history/$uuid')
          .orderByChild('created_time')
          .startAt(sinceEpoch.toDouble())
          .get()
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      // Firebase chưa khởi tạo được / mất mạng: báo lỗi để trang hiện nút thử
      // lại, thay vì im lặng trả rỗng và trông như "chưa chơi trận nào".
      throw Exception('Không đọc được kho trận từ Firebase: $e');
    }

    final raw = snap.value;
    // null = không có trận nào trong cửa sổ. Truy vấn có lọc nên KHÔNG phân
    // biệt được "kho chưa đồng bộ cho người này" với "đã đồng bộ, không có
    // trận" — cả hai đều hiện "Không có trận nào".
    if (raw == null) return const [];
    if (raw is! Map) {
      throw Exception('Kho trận sai định dạng tại history/$uuid');
    }

    final out = <MatchRecord>[];
    for (final e in raw.values) {
      if (e is! Map) continue;
      final rec = MatchRecord.fromApi(
          Map<String, dynamic>.from(e), uuid, teamUuids);
      if (rec.createdTime < sinceEpoch) continue;
      if (rec.internal && !rec.ghost && rec.viewerIsRealPlayer) out.add(rec);
    }
    out.sort((a, b) => b.createdTime - a.createdTime); // mới nhất trước
    return out;
  }
}
