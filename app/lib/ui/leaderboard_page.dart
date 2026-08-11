import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leaderboard.dart';
import '../services/leaderboard_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, this.service});

  final LeaderboardService? service;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late LeaderboardService _svc;
  late Future<Leaderboard?> _future;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? const LeaderboardService();
    _future = _svc.fetch();
  }

  void _reload() {
    setState(() {
      _future = _svc.fetch();
    });
  }

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
        child: FutureBuilder<Leaderboard?>(
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
            return _Content(board: board);
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.board});

  final Leaderboard board;

  @override
  Widget build(BuildContext context) {
    final byTier = board.byTier;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            _Header(board: board),
            const SizedBox(height: 20),
            for (final entry in byTier.entries) ...[
              _TierSection(tier: entry.key, members: entry.value),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${board.internalMatches} trận nội bộ được tính · '
                'tổng ${board.totalMatches} trận từ 01/06/2026',
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
          style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w600),
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

class _TierSection extends StatelessWidget {
  const _TierSection({required this.tier, required this.members});

  final String tier;
  final List<MemberResult> members;

  Color get _accent {
    switch (tier) {
      case 'Top 1':
        return const Color(0xFFFBBF24); // vàng
      case 'Top 2':
        return const Color(0xFF60A5FA); // xanh dương
      case 'Top 3':
        return const Color(0xFF34D399); // xanh lá
      case 'Top 4':
        return const Color(0xFFF87171); // đỏ
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
        for (final m in members) _MemberCard(member: m, accent: _accent),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.accent});

  final MemberResult member;
  final Color accent;

  @override
  Widget build(BuildContext context) {
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
              '#${member.rank}',
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
                member.avatarUrl.isNotEmpty ? NetworkImage(member.avatarUrl) : null,
            child: member.avatarUrl.isEmpty
                ? Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
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
                  member.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${member.wins}T-${member.losses}B · ${member.games} trận · '
                  'tỉ lệ ${(member.winRate * 100).toStringAsFixed(0)}%',
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
                '${member.elo}',
                style: TextStyle(
                  color: member.elo >= 0
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
