import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'blend_mask.dart';

/// Avatar thành viên kèm đồ trang trí mua trong game.
///
/// Xếp lớp từ dưới lên: hiệu ứng (vòng sáng) → ảnh avatar → khung VIP.
/// Khung và hiệu ứng là ảnh động có nền trong suốt, rộng hơn avatar nên
/// phải vẽ đè ra ngoài mép; ảnh nào lỗi thì lặng lẽ bỏ qua lớp đó.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.radius = 22,
    this.vipFrameUrl = '',
    this.effectUrl = '',
  });

  final String name;
  final String avatarUrl;
  final double radius;
  final String vipFrameUrl;
  final String effectUrl;

  // Khung/hiệu ứng vẽ rộng hơn avatar; tỉ lệ lấy theo hình thật của GPlay
  // (khung là vòng tròn rỗng giữa, phần rỗng vừa khít avatar).
  // Giữ 2 tỉ lệ gần nhau để thẻ có và không có trang trí không lệch nhau
  // quá nhiều về bề ngang (chữ bên cạnh bị dồn dòng).
  static const frameScale = 1.32;
  static const effectScale = 1.36;

  /// Bề rộng tối đa một avatar bán kính [radius] có thể chiếm khi kèm
  /// trang trí — dùng để chừa chỗ khi xếp nhiều avatar cạnh nhau.
  static double maxOuterSize(double radius) => radius * 2 * effectScale;

  double get _size => radius * 2;

  /// Kích thước ô chứa (gồm phần trang trí tràn ra ngoài) — để chừa chỗ.
  double get outerSize => (vipFrameUrl.isEmpty && effectUrl.isEmpty)
      ? _size
      : _size * (effectUrl.isNotEmpty ? effectScale : frameScale);

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: Colors.white, fontSize: radius * 0.75),
    );

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceLight,
      child: avatarUrl.isEmpty
          ? initial
          : ClipOval(
              child: Image.network(
                avatarUrl,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                // Ảnh hỏng/404/CORS -> quay về chữ cái đầu thay vì ô trống.
                errorBuilder: (_, __, ___) => Center(child: initial),
              ),
            ),
    );

    if (vipFrameUrl.isEmpty && effectUrl.isEmpty) return avatar;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Hiệu ứng có nền đen đặc -> hoà trộn "screen" để chỉ giữ phần sáng.
          if (effectUrl.isNotEmpty)
            BlendMask(
              blendMode: BlendMode.screen,
              child: _decoration(effectUrl, _size * effectScale),
            ),
          avatar,
          // Khung có nền trong suốt sẵn -> vẽ thẳng.
          if (vipFrameUrl.isNotEmpty)
            _decoration(vipFrameUrl, _size * frameScale),
        ],
      ),
    );
  }

  Widget _decoration(String url, double size) => IgnorePointer(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          // Trang trí lỗi thì bỏ qua, avatar vẫn hiện bình thường.
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
}
