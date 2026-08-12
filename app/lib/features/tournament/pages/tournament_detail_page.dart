import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../logic/knockout.dart';
import '../logic/standings.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../widgets/champion_banner.dart';
import '../widgets/fixture_card.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/score_dialog.dart';

class TournamentDetailPage extends StatelessWidget {
  const TournamentDetailPage(
      {super.key, required this.tournamentId, required this.service});

  final String tournamentId;
  final TournamentService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giải',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<Tournament?>(
        stream: service.watchOne(tournamentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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

  String _teamName(String? id) => t.teamById(id)?.name ?? '?';

  // ---- Nhập / sửa tỉ số ----

  Future<void> _editGroupFixture(BuildContext context, Fixture f) async {
    if (!await askPin(context, t.pin)) return;
    if (!context.mounted) return;
    final res = await showScoreDialog(
      context,
      teamA: _teamName(f.aId),
      teamB: _teamName(f.bId),
      firstTo: t.firstTo,
      scoreA: f.scoreA,
      scoreB: f.scoreB,
    );
    if (res == null) return;
    final updated = f.copyWith(scoreA: res.$1, scoreB: res.$2);
    final list =
        t.groupFixtures.map((x) => x.id == f.id ? updated : x).toList();
    await service.save(t.copyWith(groupFixtures: list));
  }

  Future<void> _editKoFixture(BuildContext context, KoSlot s) async {
    if (s.aId == null || s.bId == null) return;
    if (!await askPin(context, t.pin)) return;
    if (!context.mounted) return;
    final res = await showScoreDialog(
      context,
      teamA: _teamName(s.aId),
      teamB: _teamName(s.bId),
      firstTo: t.firstTo,
      scoreA: s.fixture.scoreA,
      scoreB: s.fixture.scoreB,
    );
    if (res == null) return;
    final updated = s.fixture.copyWith(scoreA: res.$1, scoreB: res.$2);
    // Đội thắng đổi -> tỉ số các vòng sau trong nhánh được reset tự động.
    await service.save(t.copyWith(koFixtures: koFixturesAfterEdit(t, updated)));
  }

  Future<void> _deleteTournament(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá giải?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Xoá "${t.name}" và toàn bộ kết quả. Không thể hoàn tác.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Xoá', style: TextStyle(color: AppColors.loss))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!await askPin(context, t.pin)) return;
    if (!context.mounted) return;
    await service.delete(t.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  // ---- Build ----

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
                onPressed: () => _deleteTournament(context),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.white38),
                label: const Text('Xoá giải',
                    style: TextStyle(color: Colors.white38)),
              ),
            ),
            const SizedBox(height: 8),
            ..._championSection(),
            for (final g in t.groups) ...[
              _Standings(
                t: t,
                group: g,
                // Giải nhiều bảng: tô sáng các đội trong vùng đi tiếp.
                advanceCount: t.structure == kStructureGroupsKnockout
                    ? t.advancePerGroup
                    : 0,
              ),
              const SizedBox(height: 12),
              _fixtures(context, g),
              const SizedBox(height: 20),
            ],
            if (t.structure == kStructureGroupsKnockout) _koSection(context),
          ],
        ),
      ),
    );
  }

  // Banner chung cuộc (nếu đã có kết quả).
  List<Widget> _championSection() {
    if (t.structure == kStructureRoundRobin) {
      if (!groupStageDone(t) || t.groups.isEmpty) return const [];
      final st = standingsFor(t, t.groups.first.teamIds, t.groupFixtures);
      if (st.isEmpty) return const [];
      return [
        ChampionBanner(
          champion: st[0].team.name,
          runnerUp: st.length > 1 ? st[1].team.name : '-',
        ),
      ];
    }
    final champId = koChampionId(t);
    if (champId == null) return const [];
    final fin = resolveKo(t).last.first;
    final loserId = champId == fin.aId ? fin.bId : fin.aId;
    return [
      ChampionBanner(
        champion: _teamName(champId),
        runnerUp: t.teamById(loserId)?.name ?? '-',
      ),
    ];
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
          FixtureCard(
            aName: _teamName(f.aId),
            bName: _teamName(f.bId),
            scoreA: f.scoreA,
            scoreB: f.scoreB,
            aWon: f.winnerId(t.firstTo) == f.aId && f.aId != null,
            bWon: f.winnerId(t.firstTo) == f.bId && f.bId != null,
            decided: f.decided(t.firstTo),
            onTap: () => _editGroupFixture(context, f),
          ),
      ],
    );
  }

  // ---- Loại trực tiếp ----

  Widget _koSection(BuildContext context) {
    if (!groupStageDone(t)) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Hoàn tất tất cả trận vòng bảng để mở nhánh loại trực tiếp.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    if (t.koFixtures.isEmpty) {
      return Center(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold, foregroundColor: Colors.black),
          icon: const Icon(Icons.account_tree),
          label: const Text('Tạo nhánh loại trực tiếp',
              style: TextStyle(fontWeight: FontWeight.w800)),
          onPressed: () async {
            if (!await askPin(context, t.pin)) return;
            await service.save(t.copyWith(koFixtures: buildKnockout(t)));
          },
        ),
      );
    }
    final rounds = resolveKo(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Loại trực tiếp',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final round in rounds) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(koRoundName(round.length),
                style: const TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w800)),
          ),
          for (final s in round)
            FixtureCard(
              aName: s.aId != null ? _teamName(s.aId) : (s.isBye ? '—' : '?'),
              bName: s.bId != null ? _teamName(s.bId) : (s.isBye ? '—' : '?'),
              scoreA: s.fixture.scoreA,
              scoreB: s.fixture.scoreB,
              aWon: s.winnerId != null && s.winnerId == s.aId,
              bWon: s.winnerId != null && s.winnerId == s.bId,
              decided: s.winnerId != null,
              onTap: (s.aId != null && s.bId != null)
                  ? () => _editKoFixture(context, s)
                  : null,
            ),
        ],
      ],
    );
  }
}

const _hs =
    TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700);
const _cs = TextStyle(color: Colors.white70, fontSize: 13);

/// Bảng điểm 1 bảng đấu; [advanceCount] > 0 thì tô sáng vùng đi tiếp.
class _Standings extends StatelessWidget {
  const _Standings({
    required this.t,
    required this.group,
    required this.advanceCount,
  });

  final Tournament t;
  final GroupDef group;
  final int advanceCount;

  @override
  Widget build(BuildContext context) {
    final rows = standingsFor(t, group.teamIds, t.groupFixtures);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Bảng điểm — ${group.name}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              if (advanceCount > 0) ...[
                const Spacer(),
                Text('top $advanceCount đi tiếp',
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Row(children: [
            SizedBox(width: 24, child: Text('#', style: _hs)),
            Expanded(child: Text('Đội', style: _hs)),
            SizedBox(
                width: 34,
                child: Text('Trận', style: _hs, textAlign: TextAlign.center)),
            SizedBox(
                width: 46,
                child: Text('T-B', style: _hs, textAlign: TextAlign.center)),
            SizedBox(
                width: 40,
                child: Text('HS', style: _hs, textAlign: TextAlign.center)),
            SizedBox(
                width: 36,
                child: Text('Điểm', style: _hs, textAlign: TextAlign.right)),
          ]),
          const Divider(color: Colors.white12),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: i < advanceCount
                  ? BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Row(children: [
                SizedBox(
                    width: 20,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: (i == 0 || i < advanceCount)
                                ? AppColors.gold
                                : Colors.white70,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    child: Text(rows[i].team.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600))),
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
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800))),
              ]),
            ),
        ],
      ),
    );
  }
}
