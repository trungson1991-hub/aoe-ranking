import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leaderboard.dart';
import '../services/leaderboard_service.dart';

// Các chế độ xem: nhãn hiển thị + key trong dữ liệu.
const List<({String key, String label})> _views = [
  (key: kTotalKey, label: 'Tổng'),
  (key: '1v1', label: '1v1'),
  (key: '2v2', label: '2v2'),
  (key: '3v3', label: '3v3'),
  (key: '4v4', label: '4v4'),
];

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, this.service});

  final LeaderboardService? service;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late LeaderboardService _svc;
  late Future<Leaderboard?> _future;
  String _view = kTotalKey;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? const LeaderboardService();
    _future = _svc.fetch();
  }

  void _reload() => setState(() => _future = _svc.fetch());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton(
        onPressed: _reload,
        backgroundColor: const Color(0xFFFBBF24),
        foregroundColor: Colors.black,
        tooltip: 'Làm mới',
        child: const Icon(Icons.refresh),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            FutureBuilder<Leaderboard?>(
              future: _future,
              builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFBBF24)),
              );
            }
            if (snap.hasError) {
              return _Message(
                icon: Icons.error_outline,
                text: 'Lỗi tải dữ liệu:\n${snap.error}',
              );
            }
            final board = snap.data;
            if (board == null || board.members.isEmpty) {
              return const _Message(
                icon: Icons.hourglass_empty,
                text:
                    'Chưa có dữ liệu.\nChạy "node scripts/compute.mjs" hoặc chờ cập nhật theo lịch.',
              );
            }
            return _Content(
              board: board,
              view: _view,
              onViewChanged: (v) => setState(() => _view = v),
            );
              },
            ),
            Positioned(
              top: 6,
              right: 6,
              child: TextButton.icon(
                onPressed: () => _showMethod(context),
                icon: const Icon(Icons.info_outline,
                    size: 18, color: Color(0xFFFBBF24)),
                label: const Text(
                  'Cách tính ELO',
                  style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showMethod(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _MethodSheet(),
  );
}

class _Content extends StatelessWidget {
  const _Content({
    required this.board,
    required this.view,
    required this.onViewChanged,
  });

  final Leaderboard board;
  final String view;
  final ValueChanged<String> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final ranked = board.ranked(view);
    // Gom theo tier, giữ thứ tự hạng.
    final byTier = <String, List<RankedMember>>{};
    for (final r in ranked) {
      byTier.putIfAbsent(r.tier.isEmpty ? 'Khác' : r.tier, () => []).add(r);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            _Header(board: board),
            const SizedBox(height: 16),
            _ViewSelector(view: view, onChanged: onViewChanged),
            const SizedBox(height: 20),
            for (final entry in byTier.entries) ...[
              _TierSection(tier: entry.key, members: entry.value),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                view == kTotalKey
                    ? '${board.internalMatches} trận nội bộ được tính'
                    : 'ELO riêng thể loại $view',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.board});

  final Leaderboard board;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Column(
      children: [
        const Text(
          '🏆  BẢNG XẾP HẠNG ELO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tính ELO từ ${dateFmt.format(board.startDateVN)}',
          style: const TextStyle(
              color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'Cập nhật: ${fmt.format(board.updatedAt.toLocal())}',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.view, required this.onChanged});

  final String view;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in _views)
          _Chip(
            label: v.label,
            selected: v.key == view,
            onTap: () => onChanged(v.key),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBBF24) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFBBF24) : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TierSection extends StatelessWidget {
  const _TierSection({required this.tier, required this.members});

  final String tier;
  final List<RankedMember> members;

  Color get _accent {
    switch (tier) {
      case 'Top 1':
        return const Color(0xFFFBBF24);
      case 'Top 2':
        return const Color(0xFF60A5FA);
      case 'Top 3':
        return const Color(0xFF34D399);
      case 'Top 4':
        return const Color(0xFFF87171);
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 20, color: _accent),
            const SizedBox(width: 8),
            Text(
              tier,
              style: TextStyle(
                color: _accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final m in members) _MemberCard(ranked: m, accent: _accent),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.ranked, required this.accent});

  final RankedMember ranked;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final m = ranked.member;
    final s = ranked.stat;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.35), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${ranked.rank}',
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF334155),
            backgroundImage:
                m.avatarUrl.isNotEmpty ? NetworkImage(m.avatarUrl) : null,
            child: m.avatarUrl.isEmpty
                ? Text(
                    m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  s.games == 0
                      ? 'chưa có trận'
                      : '${s.wins}T-${s.losses}B · ${s.games} trận · '
                          'tỉ lệ ${(s.winRate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${s.elo}',
                style: TextStyle(
                  color: s.elo >= 0
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'ELO',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// Bảng giải thích cách tính ELO (mở từ nút ⓘ).
class _MethodSheet extends StatelessWidget {
  const _MethodSheet();

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFBBF24);
    const h = TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w800);
    const b = TextStyle(color: Colors.white70, fontSize: 14, height: 1.4);
    Widget bullet(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('•  $s', style: b),
        );

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('CÁCH TÍNH ELO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            const Text('1. Trận được tính', style: h),
            const SizedBox(height: 8),
            bullet('Chỉ lấy trận trong 6 tháng gần nhất.'),
            bullet('Chỉ trận nội bộ: tất cả người chơi của cả 2 đội đều thuộc team.'),
            bullet('Loại "trận ma": ≤1 người, một đội rỗng, hoặc tổng (giết + mất quân) < 10.'),
            const SizedBox(height: 16),
            const Text('2. Điểm phong độ mỗi trận (0–1)', style: h),
            const SizedBox(height: 8),
            const Text(
              'Mỗi chỉ số được so tương đối giữa những người trong cùng trận '
              '(giỏi nhất = 1, kém nhất = 0), rồi nhân trọng số:',
              style: b,
            ),
            const SizedBox(height: 8),
            bullet('Combat 30%: giết quân 15 · ít mất quân 10 · phá công trình 5'),
            bullet('Kinh tế 25%: đào vàng 10 · nông dân đỉnh 10 · tổng dân 5'),
            bullet('Công nghệ & lên đời 25%: công nghệ 10 · lên đời nhanh 10 · đạt đời 4 (5)'),
            bullet('Bản đồ & hỗ trợ 20%: mở bản đồ 12 · bơm đồ 5 · bảo toàn quân 3'),
            const SizedBox(height: 16),
            const Text('3. Cập nhật ELO', style: h),
            const SizedBox(height: 8),
            bullet('Điểm mỗi trận: S = 0.5 × (thắng?1:0) + 0.5 × phong độ.'),
            bullet('Kỳ vọng E tính theo chênh lệch ELO trung bình 2 đội.'),
            bullet('ELO thay đổi: Δ = 28 × (S − E). Bắt đầu từ 0, có thể âm.'),
            bullet('Thắng vẫn quan trọng nhất, nhưng chơi hay/tệ ảnh hưởng điểm nhận.'),
            bullet('Theo số trận: chơi ít → ELO co về 0 (tránh mẫu nhỏ vọt top); chơi nhiều → cộng thưởng nhẹ.'),
            const SizedBox(height: 16),
            const Text('4. Các bảng', style: h),
            const SizedBox(height: 8),
            bullet('Tính riêng: Tổng và 1v1 / 2v2 / 3v3 / 4v4 (chỉ trận cân người).'),
            bullet('Xếp hạng theo ELO, chia tier: Top 1 = 3, Top 2 = 2, Top 3 = 2, Top 4 = 3 người.'),
            const SizedBox(height: 16),
            const Text(
              'Cập nhật tự động 7:00 / 14:00 / 21:00 hàng ngày (giờ VN).',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
