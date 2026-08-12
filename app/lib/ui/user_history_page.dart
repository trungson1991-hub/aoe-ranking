import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leaderboard.dart';
import '../models/match_record.dart';
import '../services/leaderboard_service.dart';
import 'match_detail_page.dart';

// Các bộ lọc thể loại: nhãn + kích thước (null = Tất cả).
const List<({String label, int? size})> _filters = [
  (label: 'Tất cả', size: null),
  (label: '1v1', size: 1),
  (label: '2v2', size: 2),
  (label: '3v3', size: 3),
  (label: '4v4', size: 4),
];

class UserHistoryPage extends StatefulWidget {
  const UserHistoryPage({
    super.key,
    required this.member,
    required this.sinceEpoch,
    required this.teamUuids,
    this.service = const LeaderboardService(),
  });

  final Member member;
  final int sinceEpoch;
  final Set<String> teamUuids;
  final LeaderboardService service;

  @override
  State<UserHistoryPage> createState() => _UserHistoryPageState();
}

class _UserHistoryPageState extends State<UserHistoryPage> {
  late Future<List<MatchRecord>> _future;
  int? _filterSize; // null = tất cả

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchUserHistory(
      widget.member.userUuid,
      sinceEpoch: widget.sinceEpoch,
      teamUuids: widget.teamUuids,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF334155),
              backgroundImage:
                  m.avatarUrl.isNotEmpty ? NetworkImage(m.avatarUrl) : null,
              child: m.avatarUrl.isEmpty
                  ? Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 13))
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(m.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<MatchRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFBBF24)),
            );
          }
          if (snap.hasError) {
            return _msg('Lỗi tải lịch sử:\n${snap.error}');
          }
          final all = snap.data ?? const [];
          final matches = _filterSize == null
              ? all
              : all.where((e) => e.symmetricSize == _filterSize).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  _filterBar(all),
                  Expanded(
                    child: matches.isEmpty
                        ? _msg('Không có trận nào ở thể loại này.')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: matches.length,
                            itemBuilder: (_, i) => _MatchTile(rec: matches[i]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterBar(List<MatchRecord> all) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in _filters)
            _Chip(
              label: f.size == null
                  ? '${f.label} (${all.length})'
                  : '${f.label} (${all.where((e) => e.symmetricSize == f.size).length})',
              selected: _filterSize == f.size,
              onTap: () => setState(() => _filterSize = f.size),
            ),
        ],
      ),
    );
  }

  Widget _msg(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15)),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBBF24) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? const Color(0xFFFBBF24) : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.rec});

  final MatchRecord rec;

  @override
  Widget build(BuildContext context) {
    final win = rec.win;
    final resultColor =
        win ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final opp = rec.opponentNames.isEmpty ? '-' : rec.opponentNames.join(', ');
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchDetailPage(record: rec)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resultColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          // Badge kết quả.
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: resultColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(win ? 'W' : 'L',
                style: TextStyle(
                    color: resultColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(rec.modeLabel,
                          style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(rec.dateVN),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('vs $opp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                    'Giết ${rec.viewer?.kills ?? 0} · Mất ${rec.viewer?.losses ?? 0}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24),
        ],
      ),
      ),
    );
  }
}
