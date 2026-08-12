import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Avatar thành viên: ảnh từ URL, không có thì hiện chữ cái đầu của tên.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.radius = 22,
  });

  final String name;
  final String avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceLight,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.white, fontSize: radius * 0.75),
            )
          : null,
    );
  }
}
