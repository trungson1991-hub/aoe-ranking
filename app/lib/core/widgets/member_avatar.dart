import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Avatar thành viên: ảnh từ URL, không có (hoặc tải lỗi) thì hiện chữ cái
/// đầu của tên. Không dùng `CircleAvatar.backgroundImage` vì khi ảnh lỗi nó
/// để lại vòng tròn xám trống và ném lỗi ra console.
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
    final initial = Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: Colors.white, fontSize: radius * 0.75),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceLight,
      child: avatarUrl.isEmpty
          ? initial
          : ClipOval(
              child: Image.network(
                avatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                // Ảnh hỏng/404/CORS -> quay về chữ cái đầu thay vì ô trống.
                errorBuilder: (_, __, ___) => Center(child: initial),
              ),
            ),
    );
  }
}
