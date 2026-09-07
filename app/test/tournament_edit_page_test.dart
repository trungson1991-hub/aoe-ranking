// Chốt lỗi: sửa TIỀN THƯỞNG (hay tên giải / ghi chú) không được xoá kết quả.
//
// Bẫy cũ: trang sửa luôn đi qua applyTeamEdits, và applyTeamEdits so bảng của
// mình với bản `latest` vừa tải từ Firebase. Chỉ cần `latest` lệch chút ít so
// với ảnh chụp trên trang (giải cũ sai định dạng bảng, hoặc ai đó vừa sửa) là
// nó tưởng "đội đã đổi bảng" và tạo lại lịch — xoá sạch tỉ số đã nhập, dù lần
// lưu này người dùng chỉ gõ tiền thưởng.
import 'package:aoe_ranking/features/leaderboard/models/leaderboard.dart';
import 'package:aoe_ranking/features/tournament/models/tournament.dart';
import 'package:aoe_ranking/features/tournament/pages/tournament_edit_page.dart';
import 'package:aoe_ranking/features/tournament/services/tournament_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSnapshot implements DataSnapshot {
  _FakeSnapshot(this._value);
  final Object? _value;
  @override
  Object? get value => _value;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeChild implements DatabaseReference {
  _FakeChild(this.store);
  final _Store store;
  @override
  Future<DataSnapshot> get() async => _FakeSnapshot(store.data);
  @override
  Future<void> set(Object? value) async {
    store.saved = Map<String, dynamic>.from(value as Map);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeRef implements DatabaseReference {
  _FakeRef(this.store);
  final _Store store;
  @override
  DatabaseReference child(String path) => _FakeChild(store);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeDb implements FirebaseDatabase {
  _FakeDb(this.store);
  final _Store store;
  @override
  DatabaseReference ref([String? path]) => _FakeRef(store);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Store {
  Map<String, dynamic>? data;
  Map<String, dynamic>? saved;
}

TournTeam tm(String id) =>
    TournTeam(id: id, name: 'Đội $id', memberUuids: [id], memberNames: [id]);
Fixture fx(String id, String stage, String? a, String? b,
        {int sa = 0, int sb = 0}) =>
    Fixture(id: id, stage: stage, aId: a, bId: b, scoreA: sa, scoreB: sb);
List<Member> roster(List<String> uuids) => [
      for (final u in uuids)
        Member(
            userUuid: u,
            name: u,
            avatarUrl: '',
            lastPlayed: 1,
            total: const ModeStat(),
            modes: const {}),
    ];

// Mở trang sửa cho `onPage`, với bản Firebase là `inDb`. Trả về store để
// đọc thứ được ghi xuống.
Future<_Store> _pumpEdit(WidgetTester tester, Tournament onPage,
    Map<String, dynamic> inDb,
    {List<String> rosterUuids = const ['t0', 't1', 't2', 't3']}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final store = _Store()..data = inDb;
  await tester.pumpWidget(MaterialApp(
    home: TournamentEditPage(
      tournament: onPage,
      roster: roster(rosterUuids),
      service: TournamentService(db: _FakeDb(store)),
    ),
  ));
  await tester.pumpAndSettle();
  return store;
}

Future<Tournament> _tapSave(WidgetTester tester, _Store store) async {
  await tester.tap(find.text('Lưu thay đổi'));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  expect(store.saved, isNotNull);
  return Tournament.fromDoc('x', store.saved!);
}

Future<void> _editPrizeAndSave(WidgetTester tester, Tournament onPage,
    Map<String, dynamic> inDb) async {
  final store =
      await _pumpEdit(tester, onPage, inDb, rosterUuids: ['t0', 't1', 't2']);
  await tester.enterText(find.widgetWithText(TextField, '🥇 Nhất'), '500000');
  await tester.pumpAndSettle();
  _lastSaved = await _tapSave(tester, store);
}

late Tournament _lastSaved;

// Giải nhiều bảng + loại trực tiếp ĐANG CHẠY: 2 bảng đã có tỉ số, nhánh KO
// đã dựng và đã đá 1 trận. Dùng chung cho các test "giải đang chạy".
Tournament _runningGroupsKo() => Tournament(
      id: 'x',
      name: 'Giải đang chạy',
      pin: '1',
      note: 'thể lệ cũ',
      format: '1v1',
      firstTo: 1,
      structure: kStructureGroupsKnockout,
      advancePerGroup: 1,
      createdAt: 0,
      status: kStatusActive,
      prizes: const [100000, 0, 0],
      teams: [tm('t0'), tm('t1'), tm('t2'), tm('t3')],
      groups: const [
        GroupDef(name: 'Bảng A', teamIds: ['t0', 't1']),
        GroupDef(name: 'Bảng B', teamIds: ['t2', 't3']),
      ],
      groupFixtures: [
        fx('gA', 'Bảng A', 't0', 't1', sa: 1),
        fx('gB', 'Bảng B', 't2', 't3', sa: 1),
      ],
      koFixtures: [fx('ko_r0_m0', 'KO', 't0', 't2', sa: 1)],
    );

void main() {
  testWidgets(
      'sửa tiền thưởng khi bản trên Firebase lệch bảng vẫn GIỮ tỉ số vòng tròn',
      (tester) async {
    final fixtures = [
      fx('f0', 'Vòng tròn', 't0', 't1', sa: 1),
      fx('f1', 'Vòng tròn', 't0', 't2', sa: 1),
      fx('f2', 'Vòng tròn', 't1', 't2', sa: 1),
    ];
    // Ảnh chụp trên trang: có bảng 'Vòng tròn' đầy đủ.
    final onPage = Tournament(
      id: 'x',
      name: 'RR',
      pin: '1',
      format: '1v1',
      firstTo: 1,
      structure: kStructureRoundRobin,
      advancePerGroup: 1,
      createdAt: 0,
      teams: [tm('t0'), tm('t1'), tm('t2')],
      groups: const [GroupDef(name: 'Vòng tròn', teamIds: ['t0', 't1', 't2'])],
      groupFixtures: fixtures,
      koFixtures: const [],
    );
    // Bản trên Firebase: CÙNG tỉ số nhưng KHÔNG lưu bảng (giải cũ sai định
    // dạng). Trước khi sửa, applyTeamEdits sẽ tưởng bảng đổi và xoá hết tỉ số.
    final inDb = onPage.toMap()..['groups'] = <dynamic>[];

    await _editPrizeAndSave(tester, onPage, inDb);

    expect(_lastSaved.prizes.first, 500000);
    final rr =
        _lastSaved.groupFixtures.where((f) => f.stage == 'Vòng tròn').toList();
    expect(rr.length, 3, reason: 'không được tạo lại/ nhân đôi lịch');
    expect(rr.where((f) => f.scoreA == 1).length, 3,
        reason: 'tỉ số vòng tròn phải còn nguyên');
  });

  // ---- Giải ĐANG CHẠY (nhiều bảng + KO) không được xáo trộn ----

  testWidgets('giải đang chạy: sửa tiền thưởng giữ nguyên vòng bảng + KO + trạng thái',
      (tester) async {
    final t = _runningGroupsKo();
    final store = await _pumpEdit(tester, t, t.toMap());
    await tester.enterText(find.widgetWithText(TextField, '🥇 Nhất'), '999000');
    await tester.pumpAndSettle();
    final saved = await _tapSave(tester, store);

    expect(saved.prizes.first, 999000);
    // Vòng bảng: đủ 2 trận, tỉ số nguyên vẹn.
    expect(saved.groupFixtures.length, 2);
    expect(saved.groupFixtures.every((f) => f.scoreA == 1), isTrue);
    // Nhánh KO nguyên vẹn.
    expect(saved.koFixtures.length, 1);
    expect(saved.koFixtures.first.scoreA, 1);
    // Cấu trúc bảng và trạng thái giải giữ nguyên.
    expect(saved.groups.map((g) => g.name).toList(), ['Bảng A', 'Bảng B']);
    expect(saved.isActive, isTrue);
  });

  testWidgets('giải đang chạy: đổi TÊN ĐỘI vẫn giữ tỉ số + KO, không tạo lại lịch',
      (tester) async {
    final t = _runningGroupsKo();
    final store = await _pumpEdit(tester, t, t.toMap());
    // Đổi tên đội đầu tiên (Đội t0) — KHÔNG đụng bảng.
    final teamName = find.widgetWithText(TextField, 'Tên đội').first;
    await tester.enterText(teamName, 'Rồng Lửa');
    await tester.pumpAndSettle();
    final saved = await _tapSave(tester, store);

    // Tên đội cập nhật, id giữ nguyên nên lịch/KO vẫn tham chiếu đúng.
    expect(saved.teamById('t0')!.name, 'Rồng Lửa');
    expect(saved.groupFixtures.length, 2);
    expect(saved.groupFixtures.every((f) => f.scoreA == 1), isTrue);
    expect(saved.koFixtures.length, 1);
    expect(saved.koFixtures.first.aId, 't0');
    expect(saved.koFixtures.first.scoreA, 1);
  });

  testWidgets('giải đang chạy: kết quả người khác vừa nhập KHÔNG bị đè khi ta chỉ sửa thưởng',
      (tester) async {
    // Trang mở với bản CŨ (Bảng B chưa đá). Trong lúc đó người khác nhập tỉ số
    // Bảng B và đá thêm 1 trận KO -> ghi vào Firebase (inDb mới hơn).
    final onPage = _runningGroupsKo();
    final newer = onPage.copyWith(
      groupFixtures: [
        fx('gA', 'Bảng A', 't0', 't1', sa: 1),
        fx('gB', 'Bảng B', 't2', 't3', sa: 1),
      ],
      koFixtures: [fx('ko_r0_m0', 'KO', 't0', 't2', sa: 1)],
    );
    final store = await _pumpEdit(tester, onPage, newer.toMap());
    await tester.enterText(find.widgetWithText(TextField, '🥇 Nhất'), '5000');
    await tester.pumpAndSettle();
    final saved = await _tapSave(tester, store);

    // Lấy bản mới nhất làm gốc: kết quả mới hơn còn nguyên, chỉ thưởng đổi.
    expect(saved.prizes.first, 5000);
    expect(saved.koFixtures.length, 1);
    expect(saved.koFixtures.first.scoreA, 1);
  });
}
