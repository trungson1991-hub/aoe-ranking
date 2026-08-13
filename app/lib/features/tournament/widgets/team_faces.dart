import 'package:flutter/material.dart';

import '../../../core/widgets/member_avatar.dart';
import '../../leaderboard/models/leaderboard.dart';

/// Dãy avatar thành viên xếp chồng nhẹ lên nhau — tiết kiệm bề ngang ở
/// những chỗ chật như bảng điểm giải.
class TeamFaces extends StatelessWidget {
  const TeamFaces({super.key, required this.uuids, required this.roster});

  final List<String> uuids;
  final Map<String, Member> roster;

  static const _r = 10.0;
  static const _overlap = 7.0;

  // Chỉ dùng khung (không dùng hiệu ứng) nên chừa theo frameScale là đủ.
  static const _outer = _r * 2 * MemberAvatar.frameScale;

  /// Bề ngang widget sẽ chiếm — để nơi gọi biết trước còn bao nhiêu chỗ cho
  /// phần chữ và quyết định có hiện avatar hay không. Trả 0 nếu không có ai.
  static double widthFor(List<String> uuids, Map<String, Member> roster) {
    final n = uuids.where((u) => roster[u] != null).length;
    return n == 0 ? 0 : (n - 1) * (_r * 2 - _overlap) + _outer + 4;
  }

  @override
  Widget build(BuildContext context) {
    final members = [
      for (final u in uuids)
        if (roster[u] != null) roster[u]!,
    ];
    if (members.isEmpty) return const SizedBox.shrink();
    // Bề ngang tính theo avatar CÓ khung (rộng hơn avatar trơn), nếu không
    // khung của người đứng cuối sẽ bị Stack cắt mất.
    return SizedBox(
      width: widthFor(uuids, roster),
      height: _outer,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          for (var i = members.length - 1; i >= 0; i--)
            Positioned(
              left: i * (_r * 2 - _overlap),
              child: MemberAvatar(
                name: members[i].name,
                avatarUrl: members[i].avatarUrl,
                radius: _r,
                vipFrameUrl: members[i].vipFrameUrl,
              ),
            ),
        ],
      ),
    );
  }
}
