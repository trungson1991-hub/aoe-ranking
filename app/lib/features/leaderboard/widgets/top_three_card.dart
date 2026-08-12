import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Hiệu ứng "ra mắt" cho thẻ top 3:
/// - Thẻ trượt lên + phóng nhẹ (overshoot) + hiện dần, so le theo hạng.
/// - Một vệt sáng vàng quét ngang thẻ đúng 1 lần.
///
/// Đảm bảo mượt: phần vào sân chỉ dùng Fade/Slide/Scale (thao tác
/// compositor trên layer đã raster — thẻ con đã có RepaintBoundary,
/// KHÔNG vẽ lại nội dung thẻ từng frame). Vệt sáng là 1 layer nhỏ
/// trượt ngang; animation kết thúc thì overlay được gỡ hẳn khỏi cây
/// widget — sau đó thẻ tĩnh 100% như cũ, cuộn không tốn thêm gì.
class TopThreeCard extends StatefulWidget {
  const TopThreeCard({super.key, required this.rank, required this.child});

  final int rank; // 1..3 — quyết định độ trễ so le
  final Widget child;

  @override
  State<TopThreeCard> createState() => _TopThreeCardState();
}

class _TopThreeCardState extends State<TopThreeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _done = false;

  late final double _t0 = 0.10 * (widget.rank - 1); // so le theo hạng

  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Interval(_t0, _t0 + 0.30, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _c,
    curve: Interval(_t0, _t0 + 0.35, curve: Curves.easeOutCubic),
  ));
  late final Animation<double> _scale = Tween(begin: 0.90, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: Interval(_t0, _t0 + 0.40, curve: Curves.easeOutBack),
    ),
  );
  // Vệt sáng chạy sau khi thẻ đã vào sân.
  late final Animation<double> _shine = CurvedAnimation(
    parent: _c,
    curve: Interval(_t0 + 0.40, _t0 + 0.62, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((s) {
      // Xong thì gỡ overlay vệt sáng -> cây widget trở về tĩnh hoàn toàn.
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Stack(
            children: [
              widget.child,
              Positioned.fill(
                // Thẻ có margin-bottom bên trong -> né vùng margin.
                bottom: 12,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedBuilder(
                      animation: _shine,
                      // Vệt sáng vẽ 1 lần (child), mỗi frame chỉ đổi vị trí.
                      builder: (_, bar) => Align(
                        alignment: Alignment(-2.2 + 4.4 * _shine.value, 0),
                        child: bar,
                      ),
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 56,
                          height: 240,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.gold.withValues(alpha: 0),
                                AppColors.gold.withValues(alpha: 0.30),
                                Colors.white.withValues(alpha: 0.42),
                                AppColors.gold.withValues(alpha: 0.30),
                                AppColors.gold.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
