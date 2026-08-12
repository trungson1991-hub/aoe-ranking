import 'package:flutter/material.dart';

import '../models/tournament.dart';
import '../services/tournament_service.dart';
import 'tournaments_page.dart' show askPin;

class TournamentDetailPage extends StatelessWidget {
  const TournamentDetailPage(
      {super.key, required this.tournamentId, required this.service});

  final String tournamentId;
  final TournamentService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Chi tiết giải',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<Tournament?>(
        stream: service.watchOne(tournamentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFBBF24)));
          }
          final t = snap.data;
          if (t == null) {
            return const Center(
                child: Text('Giải không tồn tại',
                    style: TextStyle(color: Colors.white54)));
          }
          return _Body(t: t, service: service);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.service});

  final Tournament t;
  final TournamentService service;

  bool get _allDone =>
      t.groupFixtures.isNotEmpty &&
      t.groupFixtures.every((f) => f.decided(t.firstTo));

  Future<void> _editFixture(BuildContext context, Fixture f) async {
    if (!await askPin(context, t.pin)) return;
    if (!context.mounted) return;
    var a = f.scoreA;
    var b = f.scoreB;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            '${t.teamById(f.aId)?.name ?? '?'}  vs  ${t.teamById(f.bId)?.name ?? '?'}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepper(a, (v) => setLocal(() => a = v), t.firstTo),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('-',
                    style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
              _stepper(b, (v) => setLocal(() => b = v), t.firstTo),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lưu')),
          ],
        ),
      ),
    );
    if (res == true) {
      final updated = f.copyWith(scoreA: a, scoreB: b);
      final list =
          t.groupFixtures.map((x) => x.id == f.id ? updated : x).toList();
      await service.save(t.copyWith(groupFixtures: list));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${t.format} · chạm ${t.firstTo} · ${t.teams.length} đội',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  if (!await askPin(context, t.pin)) return;
                  if (!context.mounted) return;
                  await service.delete(t.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.white38),
                label: const Text('Xoá giải',
                    style: TextStyle(color: Colors.white38)),
              ),
            ),
            const SizedBox(height: 8),
            if (_allDone) _champion(),
            for (final g in t.groups) ...[
              _standings(g),
              const SizedBox(height: 12),
              _fixtures(context, g),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _champion() {
    final st = standingsFor(t, t.groups.first.teamIds, t.groupFixtures);
    if (st.isEmpty) return const SizedBox.shrink();
    final champ = st[0].team.name;
    final runner = st.length > 1 ? st[1].team.name : '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFB45309)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('🏆 KẾT QUẢ CHUNG CUỘC',
              style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 8),
          Text('🥇 Vô địch: $champ',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          Text('🥈 Á quân: $runner',
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _standings(GroupDef g) {
    final rows = standingsFor(t, g.teamIds, t.groupFixtures);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bảng điểm — ${g.name}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          // Header
          Row(children: const [
            SizedBox(width: 24, child: Text('#', style: _hs)),
            Expanded(child: Text('Đội', style: _hs)),
            SizedBox(width: 34, child: Text('Trận', style: _hs, textAlign: TextAlign.center)),
            SizedBox(width: 46, child: Text('T-B', style: _hs, textAlign: TextAlign.center)),
            SizedBox(width: 40, child: Text('HS', style: _hs, textAlign: TextAlign.center)),
            SizedBox(width: 36, child: Text('Điểm', style: _hs, textAlign: TextAlign.right)),
          ]),
          const Divider(color: Colors.white12),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                    width: 24,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: i == 0
                                ? const Color(0xFFFBBF24)
                                : Colors.white70,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    child: Text(rows[i].team.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 34,
                    child: Text('${rows[i].played}',
                        textAlign: TextAlign.center, style: _cs)),
                SizedBox(
                    width: 46,
                    child: Text('${rows[i].wins}-${rows[i].losses}',
                        textAlign: TextAlign.center, style: _cs)),
                SizedBox(
                    width: 40,
                    child: Text(
                        '${rows[i].gameDiff >= 0 ? '+' : ''}${rows[i].gameDiff}',
                        textAlign: TextAlign.center, style: _cs)),
                SizedBox(
                    width: 36,
                    child: Text('${rows[i].points}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontWeight: FontWeight.w800))),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _fixtures(BuildContext context, GroupDef g) {
    final fs = t.groupFixtures.where((f) => f.stage == g.name).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Các trận',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final f in fs)
          InkWell(
            onTap: () => _editFixture(context, f),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: f.decided(t.firstTo)
                        ? const Color(0xFF34D399).withOpacity(0.4)
                        : Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.teamById(f.aId)?.name ?? '?',
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: f.winnerId(t.firstTo) == f.aId
                                ? const Color(0xFF86EFAC)
                                : Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('${f.scoreA} - ${f.scoreB}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    child: Text(t.teamById(f.bId)?.name ?? '?',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: f.winnerId(t.firstTo) == f.bId
                                ? const Color(0xFF86EFAC)
                                : Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 14, color: Colors.white24),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static Widget _stepper(int value, ValueChanged<int> onChanged, int max) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
        ),
        Text('$value',
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
        ),
      ],
    );
  }
}

const _hs = TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700);
const _cs = TextStyle(color: Colors.white70, fontSize: 13);
