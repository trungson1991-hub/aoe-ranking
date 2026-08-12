import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leaderboard.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import 'tournament_create_page.dart';
import 'tournament_detail_page.dart';

class TournamentsPage extends StatelessWidget {
  TournamentsPage({super.key, required this.roster});

  final List<Member> roster;
  final TournamentService _service = TournamentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Giải đấu',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFBBF24),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Tạo giải', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TournamentCreatePage(roster: roster, service: _service),
          ));
        },
      ),
      body: StreamBuilder<List<Tournament>>(
        stream: _service.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFBBF24)));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Lỗi kết nối:\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54)),
              ),
            );
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(
              child: Text('Chưa có giải nào.\nBấm "Tạo giải" để bắt đầu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) => _TournamentTile(t: list[i], service: _service),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TournamentTile extends StatelessWidget {
  const _TournamentTile({required this.t, required this.service});

  final Tournament t;
  final TournamentService service;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(t.createdAt * 1000));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        title: Text(t.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${t.format} · chạm ${t.firstTo} · ${t.teams.length} đội · $date',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TournamentDetailPage(tournamentId: t.id, service: service),
        )),
      ),
    );
  }
}

// Hộp thoại nhập PIN của giải. Trả về true nếu khớp expectedPin.
Future<bool> askPin(BuildContext context, String expectedPin) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Nhập PIN của giải',
          style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: ctrl,
        obscureText: true,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: 'PIN'),
        onSubmitted: (_) => Navigator.pop(ctx, ctrl.text == expectedPin),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text == expectedPin),
            child: const Text('OK')),
      ],
    ),
  );
  if (ok != true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN sai hoặc đã huỷ')),
    );
  }
  return ok == true;
}
