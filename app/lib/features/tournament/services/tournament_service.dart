import 'package:firebase_database/firebase_database.dart';

import '../models/tournament.dart';

class TournamentService {
  TournamentService({FirebaseDatabase? db})
      : _ref = (db ?? FirebaseDatabase.instance).ref('tournaments');

  final DatabaseReference _ref;

  // Chuyển giá trị RTDB (Map<Object?,Object?>) sang Map<String,dynamic>.
  static Map<String, dynamic> _asMap(Object? v) =>
      Map<String, dynamic>.from(v as Map);

  // Theo dõi realtime danh sách giải. Không sắp xếp ở đây — trang hiển thị
  // tự sắp theo tiêu chí của nó (đang diễn ra trước, rồi mới nhất trước).
  Stream<List<Tournament>> watchAll() {
    return _ref.onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null) return <Tournament>[];
      return _asMap(val)
          .entries
          .map((e) => Tournament.fromDoc(e.key, _asMap(e.value)))
          .toList();
    });
  }

  // Theo dõi realtime 1 giải.
  Stream<Tournament?> watchOne(String id) {
    return _ref.child(id).onValue.map((event) {
      final val = event.snapshot.value;
      if (val == null) return null;
      return Tournament.fromDoc(id, _asMap(val));
    });
  }

  // Đọc 1 lần bản mới nhất (dùng trước khi ghi để không đè mất thay đổi
  // của người khác trong lúc mình đang mở trang sửa).
  Future<Tournament?> getOnce(String id) async {
    final snap = await _ref.child(id).get();
    final val = snap.value;
    if (val == null) return null;
    return Tournament.fromDoc(id, _asMap(val));
  }

  // Tạo giải mới, trả về id.
  Future<String> create(Tournament Function(String id) build) async {
    final id = _ref.push().key!;
    final t = build(id);
    await _ref.child(id).set(t.toMap());
    return id;
  }

  Future<void> save(Tournament t) => _ref.child(t.id).set(t.toMap());

  Future<void> delete(String id) => _ref.child(id).remove();
}
