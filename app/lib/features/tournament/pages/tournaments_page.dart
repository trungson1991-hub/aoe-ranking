import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/message_view.dart';
import '../../leaderboard/models/leaderboard.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import 'tournament_create_page.dart';
import 'tournament_detail_page.dart';

class TournamentsPage extends StatefulWidget {
  const TournamentsPage({super.key, required this.roster});

  final List<Member> roster;

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage> {
  // Giữ service trong State để stream không bị subscribe lại mỗi lần rebuild.
  late final TournamentService _service = TournamentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giải đấu',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Tạo giải',
            style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                TournamentCreatePage(roster: widget.roster, service: _service),
          ));
        },
      ),
      body: StreamBuilder<List<Tournament>>(
        stream: _service.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return MessageView(
                icon: Icons.cloud_off, text: 'Lỗi kết nối:\n${snap.error}');
          }
          // Giải đang diễn ra lên đầu, trong mỗi nhóm thì mới nhất trước.
          final list = [...(snap.data ?? const <Tournament>[])]..sort((a, b) {
              final ra = a.isActive ? 0 : 1;
              final rb = b.isActive ? 0 : 1;
              if (ra != rb) return ra - rb;
              return b.createdAt - a.createdAt;
            });
          if (list.isEmpty) {
            return const MessageView(
                icon: Icons.emoji_events_outlined,
                text: 'Chưa có giải nào.\nBấm "Tạo giải" để bắt đầu.');
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) => _TournamentTile(
                    t: list[i], service: _service, roster: widget.roster),
              ),
            ),
          );
        },
      ),
    );
  }
}

final _dateFmt = DateFormat('dd/MM/yyyy');

class _TournamentTile extends StatelessWidget {
  const _TournamentTile(
      {required this.t, required this.service, required this.roster});

  final Tournament t;
  final TournamentService service;
  final List<Member> roster;

  @override
  Widget build(BuildContext context) {
    final date =
        _dateFmt.format(DateTime.fromMillisecondsSinceEpoch(t.createdAt * 1000));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        title: Row(
          children: [
            Flexible(
              child: Text(t.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            _StatusChip(t: t),
          ],
        ),
        subtitle: Text(
          '${t.format} · chạm ${t.firstTo} · ${t.teams.length} đội · $date',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TournamentDetailPage(
              tournamentId: t.id, service: service, roster: roster),
        )),
      ),
    );
  }
}

/// Nhãn trạng thái giải trên danh sách.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.t});

  final Tournament t;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = t.isActive
        ? ('Đang diễn ra', AppColors.done)
        : t.isFinished
            ? ('Đã kết thúc', AppColors.gold)
            : ('Đã huỷ', Colors.white38);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
