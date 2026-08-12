// Sửa đội/bảng SAU khi giải đã tạo (biến động thành viên, chuyển bảng...).
import '../models/tournament.dart';
import 'round_robin.dart';

/// Các bảng có danh sách đội THAY ĐỔI so với hiện tại (so theo tập id đội).
Set<String> changedGroupStages(Tournament t, List<GroupDef> newGroups) {
  final changed = <String>{};
  for (final g in newGroups) {
    GroupDef? old;
    for (final x in t.groups) {
      if (x.name == g.name) old = x;
    }
    final oldSet = {...(old?.teamIds ?? const <String>[])};
    if (oldSet.length != g.teamIds.length || !oldSet.containsAll(g.teamIds)) {
      changed.add(g.name);
    }
  }
  return changed;
}

/// Áp thay đổi đội/bảng vào giải:
/// - Đổi tên đội / thành viên (id đội giữ nguyên): lịch & kết quả giữ nguyên.
/// - Bảng nào có đội thay đổi: tạo lại lịch vòng tròn của bảng đó (mất kết quả
///   các trận trong bảng đó); bảng không đổi giữ nguyên kết quả.
/// - Có bảng thay đổi thì nhánh loại trực tiếp (nếu đã tạo) bị xoá — seed từ
///   vòng bảng không còn đúng.
Tournament applyTeamEdits(
  Tournament t, {
  required List<TournTeam> teams,
  required List<GroupDef> groups,
}) {
  final changed = changedGroupStages(t, groups);
  if (changed.isEmpty) {
    return t.copyWith(teams: teams, groups: groups);
  }
  final fixtures = <Fixture>[
    ...t.groupFixtures.where((f) => !changed.contains(f.stage)),
    for (final g in groups)
      if (changed.contains(g.name))
        ...generateRoundRobin(g.teamIds, stage: g.name),
  ];
  return t.copyWith(
    teams: teams,
    groups: groups,
    groupFixtures: fixtures,
    koFixtures: const [],
  );
}
