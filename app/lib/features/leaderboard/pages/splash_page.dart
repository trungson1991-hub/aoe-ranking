import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/leaderboard.dart';
import '../services/leaderboard_service.dart';
import 'leaderboard_page.dart';

/// Kích thước logo, phải KHỚP `<image name="LaunchImage" width/height>` trong
/// LaunchScreen.storyboard. Lệch là lúc iOS bàn giao cho Flutter sẽ thấy logo
/// nhảy cỡ một cái.
const double kSplashLogoSize = 220;

/// Giữ màn hình khởi động cho tới khi nạp xong dữ liệu rồi mới vào Home, để
/// người dùng không thấy Home rỗng rồi mới lấp dần vào.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.service});

  final LeaderboardService? service;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final LeaderboardService _svc =
      widget.service ?? const LeaderboardService();
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Sau frame đầu: precacheImage cần context đã có MediaQuery/DefaultAssetBundle.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final board = await _svc.fetch();
      await _precacheAvatars(board);
      if (!mounted) return;
      // Future của route chỉ hoàn tất khi trang bị pop — không phải thứ để chờ.
      unawaited(Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) =>
            LeaderboardPage(service: widget.service, preloaded: board),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      )));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Tải sẵn avatar để danh sách hiện ra là đủ ảnh, không lấp dần lúc cuộn.
  Future<void> _precacheAvatars(Leaderboard board) async {
    if (!mounted) return;
    final jobs = <Future<void>>[
      for (final m in board.members)
        if (m.avatarUrl.isNotEmpty)
          precacheImage(NetworkImage(m.avatarUrl), context,
              onError: (_, __) {}),
    ];
    if (jobs.isEmpty) return;
    // Một ảnh hỏng hoặc mạng chậm KHÔNG được phép giam người dùng ở splash:
    // hết giờ thì vào Home luôn, ảnh nào thiếu tự tải lúc hiện.
    await Future.wait(jobs)
        .timeout(const Duration(seconds: 8), onTimeout: () => <void>[]);
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Logo đặt chính giữa màn hình, đúng chỗ LaunchScreen.storyboard đặt.
          Center(
            child: Image.asset('assets/logo.png',
                width: kSplashLogoSize, height: kSplashLogoSize),
          ),
          // Phần trạng thái nằm DƯỚI logo bằng Align chứ không dùng Column:
          // Column sẽ đẩy logo lệch lên và làm hỏng sự liền mạch ở trên.
          Align(
            alignment: const Alignment(0, 0.5),
            child: _error == null ? const _Loading() : _Error(onRetry: _retry),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.gold),
        ),
        SizedBox(height: 14),
        Text('Đang tải bảng xếp hạng…',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, color: Colors.white38, size: 30),
        const SizedBox(height: 10),
        const Text('Không tải được bảng xếp hạng.',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.background,
          ),
        ),
      ],
    );
  }
}
