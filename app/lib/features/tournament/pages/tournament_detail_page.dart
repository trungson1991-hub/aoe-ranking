import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/message_view.dart';
import '../../leaderboard/models/leaderboard.dart';
import '../logic/fixture_edit.dart';
import '../logic/share_link.dart';
import '../logic/knockout.dart';
import '../logic/standings.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../widgets/champion_banner.dart';
import '../widgets/fixture_card.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/score_dialog.dart';
import 'tournament_edit_page.dart';

class TournamentDetailPage extends StatelessWidget {
  const TournamentDetailPage({
    super.key,
    required this.tournamentId,
    required this.service,
    this.roster = const [],
  });

  final String tournamentId;
  final TournamentService service;
  final List<Member> roster;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giải',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Sao chép link giải',
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () async {
              final link = tournamentShareLink(Uri.base, tournamentId);
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Đã sao chép link giải:\n$link')));
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<Tournament?>(
        stream: service.watchOne(tournamentId),
        builder: (context, snap) {
          if (snap.hasError) {
            return MessageView(
                icon: Icons.cloud_off, text: 'Lỗi kết nối:\n${snap.error}');
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = snap.data;
          if (t == null) {
            return const MessageView(
                icon: Icons.search_off, text: 'Giải không tồn tại hoặc đã bị xoá');
          }
          return _Body(t: t, service: service, roster: roster);
        },
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.t, required this.service, required this.roster});

  final Tournament t;
  final TournamentService service;
  final List<Member> roster;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  // Đã nhập PIN đúng 1 lần trong phiên xem giải này -> các lần sửa sau
  // không phải gõ lại (đỡ phiền khi nhập kết quả cả buổi thi đấu).
  bool _unlocked = false;

  // Bảng đang ở chế độ kéo-thả sắp xếp thứ tự trận (null = không).
  String? _reorderingStage;

  Tournament get t => widget.t;
  TournamentService get service => widget.service;

  String _teamName(String? id) => t.teamById(id)?.name ?? '?';
  List<String> _teamMembers(String? id) =>
      t.teamById(id)?.memberNames ?? const [];

  Future<bool> _ensurePin() async {
    if (_unlocked) return true;
    final ok = await askPin(context, t.pin);
    if (ok && mounted) setState(() => _unlocked = true);
    return ok;
  }

  /// Ghi lên Firebase kèm timeout + báo lỗi. Trước đây mọi thao tác ghi ở
  /// trang này chạy kiểu "bắn rồi quên": mất mạng thì lỗi rơi vào hư không,
  /// giao diện không đổi và người dùng tưởng đã lưu.
  Future<bool> _saveGuarded(Tournament updated, {String? successMessage}) async {
    try {
      await service.save(updated).timeout(const Duration(seconds: 15));
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lưu không thành công: $e')),
        );
      }
      return false;
    }
  }

  // ---- Nhập / sửa tỉ số ----

  Future<void> _editGroupFixture(Fixture f) async {
    if (!t.isActive) return;
    if (!await _ensurePin()) return;
    if (!mounted) return;
    final res = await showScoreDialog(
      context,
      teamA: _teamName(f.aId),
      teamB: _teamName(f.bId),
      membersA: _teamMembers(f.aId),
      membersB: _teamMembers(f.bId),
      firstTo: t.firstTo,
      scoreA: f.scoreA,
      scoreB: f.scoreB,
    );
    if (res == null) return;
    // Khớp theo (id, stage) — không ghi đè nhầm trận của bảng khác.
    await _saveGuarded(t.copyWith(
        groupFixtures: groupFixturesAfterEdit(t, f, res.$1, res.$2)));
  }

  Future<void> _editKoFixture(KoSlot s) async {
    if (!t.isActive) return;
    if (s.aId == null || s.bId == null) return;
    if (!await _ensurePin()) return;
    if (!mounted) return;
    final res = await showScoreDialog(
      context,
      teamA: _teamName(s.aId),
      teamB: _teamName(s.bId),
      membersA: _teamMembers(s.aId),
      membersB: _teamMembers(s.bId),
      firstTo: t.firstTo,
      scoreA: s.fixture.scoreA,
      scoreB: s.fixture.scoreB,
    );
    if (res == null) return;
    final updated = s.fixture.copyWith(scoreA: res.$1, scoreB: res.$2);
    // Đội thắng đổi -> tỉ số các vòng sau trong nhánh được reset tự động.
    await _saveGuarded(
        t.copyWith(koFixtures: koFixturesAfterEdit(t, updated)));
  }

  /// Đổi tên giải nhanh bằng dialog (không phải vào trang sửa đội).
  Future<void> _renameTournament() async {
    if (!await _ensurePin()) return;
    if (!mounted) return;
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: t.name),
    );
    if (newName == null || newName.isEmpty || newName == t.name) return;
    await _saveGuarded(t.copyWith(name: newName),
        successMessage: 'Đã đổi tên giải thành "$newName"');
  }

  /// Dựng lại nhánh KO từ bảng xếp hạng vòng bảng hiện tại.
  /// Cần thiết khi sửa kết quả vòng bảng làm đổi thứ hạng — nhánh cũ vẫn
  /// giữ cặp đấu theo bảng xếp hạng cũ và trước đây không có cách nào sửa.
  Future<void> _rebuildKnockout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo lại nhánh loại trực tiếp?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Nhánh sẽ được dựng lại theo thứ hạng vòng bảng hiện tại. '
          'Toàn bộ tỉ số đã nhập ở vòng loại trực tiếp sẽ mất.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tạo lại',
                  style: TextStyle(color: AppColors.gold))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!await _ensurePin()) return;
    await _saveGuarded(t.copyWith(koFixtures: buildKnockout(t)),
        successMessage: 'Đã tạo lại nhánh loại trực tiếp');
  }

  Future<void> _openEditTeams() async {
    if (!t.isActive) return;
    if (!await _ensurePin()) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TournamentEditPage(
        tournament: t,
        roster: widget.roster,
        service: service,
      ),
    ));
  }

  // Đổi trạng thái giải (kết thúc / huỷ / mở lại), có xác nhận + PIN.
  Future<void> _setStatus(
    String status, {
    String? confirmTitle,
    String? confirmBody,
  }) async {
    if (confirmTitle != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(confirmTitle, style: const TextStyle(color: Colors.white)),
          content:
              Text(confirmBody ?? '', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Đồng ý',
                    style: TextStyle(color: AppColors.gold))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (!await _ensurePin()) return;
    // Ghi lại thời điểm kết thúc: điểm thưởng giải chỉ tính trong cửa sổ
    // 1 năm gần nhất nên cần mốc này (giải cũ chưa có thì script tạm dùng
    // ngày tạo). Mở lại giải thì xoá mốc.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _saveGuarded(t.copyWith(
      status: status,
      finishedAt: status == kStatusFinished ? now : 0,
    ));
  }

  Future<void> _deleteTournament() async {
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
    if (confirmed != true || !mounted) return;
    // Xoá là thao tác huỷ diệt -> luôn hỏi PIN, kể cả khi đã mở khoá.
    if (!await askPin(context, t.pin)) return;
    if (!mounted) return;
    // Lấy Navigator/Messenger TRƯỚC khi xoá: RTDB bắn sự kiện ngay lập tức
    // khiến StreamBuilder bỏ trang này khỏi cây widget, lúc đó `mounted` đã
    // false và lệnh pop sau `await` sẽ không bao giờ chạy (kẹt màn hình).
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.delete(t.id).timeout(const Duration(seconds: 15));
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Xoá không thành công: $e')));
    }
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    // Giải nhánh KO 1 lần cho cả trang (trước đây resolveKo chạy 3 lần/build).
    final rounds = t.structure == kStructureGroupsKnockout
        ? resolveKo(t)
        : const <List<KoSlot>>[];
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
            ..._prizeRow(),
            const SizedBox(height: 8),
            Row(
              children: [
                if (t.isActive) _lockChip(),
                const Spacer(),
                _actionsMenu(),
              ],
            ),
            const SizedBox(height: 8),
            ..._statusBanner(),
            if (!t.isCancelled) ..._championSection(rounds),
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
              _fixtures(g),
              const SizedBox(height: 20),
            ],
            if (t.structure == kStructureGroupsKnockout) _koSection(rounds),
          ],
        ),
      ),
    );
  }

  /// Dòng tiền thưởng (chỉ hiện các hạng có tiền).
  List<Widget> _prizeRow() {
    const medals = ['🥇', '🥈', '🥉'];
    final parts = <String>[
      for (var i = 0; i < t.prizes.length && i < 3; i++)
        if (t.prizes[i] > 0) '${medals[i]} ${formatMoney(t.prizes[i])}',
    ];
    if (parts.isEmpty) return const [];
    return [
      const SizedBox(height: 4),
      Text(
        'Giải thưởng:  ${parts.join('   ')}',
        style: const TextStyle(
            color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ];
  }

  /// Menu hành động (⋮): sửa đội, kết thúc, huỷ, mở lại, xoá — tuỳ trạng thái.
  Widget _actionsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white54),
      color: AppColors.surfaceLight,
      onSelected: (v) {
        switch (v) {
          case 'rename':
            _renameTournament();
          case 'edit':
            _openEditTeams();
          case 'finish':
            _setStatus(
              kStatusFinished,
              confirmTitle: 'Kết thúc giải?',
              confirmBody: 'Chốt kết quả hiện tại và khoá nhập/sửa tỉ số. '
                  'Có thể "Mở lại giải" nếu cần.',
            );
          case 'cancel':
            _setStatus(
              kStatusCancelled,
              confirmTitle: 'Huỷ giải?',
              confirmBody: 'Giải bị đánh dấu ĐÃ HUỶ, không tính kết quả '
                  'và khoá nhập/sửa tỉ số. Có thể "Mở lại giải" nếu cần.',
            );
          case 'reopen':
            _setStatus(
              kStatusActive,
              confirmTitle: 'Mở lại giải?',
              confirmBody: 'Giải trở lại trạng thái đang diễn ra và có thể '
                  'nhập/sửa kết quả. Điểm thưởng ELO của giải này sẽ ngừng '
                  'được tính cho tới khi kết thúc lại.',
            );
          case 'delete':
            _deleteTournament();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'rename',
          child: Text('✏️ Đổi tên giải',
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
        if (t.isActive) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Text('👥 Sửa đội & bảng',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
          const PopupMenuItem(
            value: 'finish',
            child: Text('🏁 Kết thúc giải',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
          const PopupMenuItem(
            value: 'cancel',
            child: Text('🚫 Huỷ giải',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ] else
          const PopupMenuItem(
            value: 'reopen',
            child: Text('🔓 Mở lại giải',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('🗑️ Xoá giải',
              style: TextStyle(color: AppColors.loss, fontSize: 14)),
        ),
      ],
    );
  }

  /// Banner trạng thái khi giải đã kết thúc / đã huỷ.
  List<Widget> _statusBanner() {
    if (t.isActive) return const [];
    final finished = t.isFinished;
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: finished
                ? AppColors.gold.withValues(alpha: 0.5)
                : Colors.white24,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                finished
                    ? '🏁 Giải đã kết thúc — kết quả đã chốt'
                    : '🚫 Giải đã huỷ — không tính kết quả',
                style: TextStyle(
                  color: finished ? AppColors.gold : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _setStatus(
                kStatusActive,
                confirmTitle: 'Mở lại giải?',
                confirmBody: 'Giải trở lại trạng thái đang diễn ra và có thể '
                    'nhập/sửa kết quả. Điểm thưởng ELO của giải này sẽ ngừng '
                    'được tính cho tới khi kết thúc lại.',
              ),
              child: const Text('Mở lại',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      ),
    ];
  }

  /// Chip trạng thái khoá: bấm để mở khoá trước (nhập PIN) hoặc khoá lại.
  Widget _lockChip() {
    return Tooltip(
      message: _unlocked
          ? 'Đã mở khoá: bấm vào trận để sửa kết quả. Bấm chip để khoá lại.'
          : 'Bấm để nhập PIN, mở khoá sửa kết quả cho cả phiên.',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (_unlocked) {
            setState(() => _unlocked = false);
          } else {
            await _ensurePin();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _unlocked
                  ? AppColors.done.withValues(alpha: 0.6)
                  : Colors.white24,
            ),
          ),
          child: Text(
            _unlocked ? '🔓 Đã mở khoá' : '🔒 Nhập kết quả',
            style: TextStyle(
              color: _unlocked ? AppColors.done : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // Banner chung cuộc (nếu đã có kết quả). [rounds] là nhánh KO đã giải sẵn
  // (tính 1 lần cho cả trang thay vì mỗi chỗ gọi resolveKo lại một lần).
  List<Widget> _championSection(List<List<KoSlot>> rounds) {
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
    if (rounds.isEmpty || rounds.last.length != 1) return const [];
    final fin = rounds.last.first;
    final champId = fin.winnerId;
    if (champId == null) return const [];
    final loserId = champId == fin.aId ? fin.bId : fin.aId;
    return [
      ChampionBanner(
        champion: _teamName(champId),
        runnerUp: t.teamById(loserId)?.name ?? '-',
      ),
    ];
  }

  Widget _fixtures(GroupDef g) {
    final fs = t.groupFixtures.where((f) => f.stage == g.name).toList();
    final reordering = _reorderingStage == g.name;

    Widget card(Fixture f, {bool tappable = true}) => FixtureCard(
          aName: _teamName(f.aId),
          bName: _teamName(f.bId),
          aMembers: _teamMembers(f.aId),
          bMembers: _teamMembers(f.bId),
          scoreA: f.scoreA,
          scoreB: f.scoreB,
          aWon: f.winnerId(t.firstTo) == f.aId && f.aId != null,
          bWon: f.winnerId(t.firstTo) == f.bId && f.bId != null,
          decided: f.decided(t.firstTo),
          // Giải đã kết thúc/huỷ -> chỉ xem, không sửa.
          onTap: tappable && t.isActive ? () => _editGroupFixture(f) : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Các trận',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (fs.length > 1 && t.isActive)
              TextButton.icon(
                onPressed: () async {
                  if (reordering) {
                    setState(() => _reorderingStage = null);
                    return;
                  }
                  if (!await _ensurePin()) return;
                  if (mounted) setState(() => _reorderingStage = g.name);
                },
                icon: Icon(reordering ? Icons.check : Icons.swap_vert,
                    size: 16,
                    color: reordering ? AppColors.done : AppColors.gold),
                label: Text(reordering ? 'Xong' : 'Sắp xếp',
                    style: TextStyle(
                        color: reordering ? AppColors.done : AppColors.gold,
                        fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (reordering && t.isActive)
          // Kéo-thả để đổi thứ tự trận; mỗi lần thả lưu luôn lên Firebase.
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: fs.length,
            // onReorderItem: newIndex đã được điều chỉnh sẵn sau khi bỏ item.
            onReorderItem: (oldI, newI) {
              _saveGuarded(t.copyWith(
                  groupFixtures: reorderStageFixtures(
                      t.groupFixtures, g.name, oldI, newI)));
            },
            itemBuilder: (_, i) => Row(
              key: ValueKey('${g.name}_${fs[i].id}'),
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8, bottom: 6),
                    child:
                        Icon(Icons.drag_indicator, color: Colors.white38),
                  ),
                ),
                Expanded(child: card(fs[i], tappable: false)),
              ],
            ),
          )
        else
          for (final f in fs) card(f),
      ],
    );
  }

  // ---- Loại trực tiếp ----

  Widget _koSection(List<List<KoSlot>> rounds) {
    // CHƯA có nhánh KO: hướng dẫn / nút tạo (tuỳ vòng bảng xong chưa).
    if (t.koFixtures.isEmpty) {
      if (!t.isActive) return const SizedBox.shrink();
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
      return Center(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold, foregroundColor: Colors.black),
          icon: const Icon(Icons.account_tree),
          label: const Text('Tạo nhánh loại trực tiếp',
              style: TextStyle(fontWeight: FontWeight.w800)),
          onPressed: () async {
            if (!await _ensurePin()) return;
            await _saveGuarded(t.copyWith(koFixtures: buildKnockout(t)));
          },
        ),
      );
    }
    // ĐÃ có nhánh KO -> luôn hiển thị, kể cả khi ai đó sửa lại một trận vòng
    // bảng làm `groupStageDone` thành false (trước đây cả nhánh biến mất).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Loại trực tiếp',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const Spacer(),
            if (t.isActive)
              TextButton.icon(
                onPressed: _rebuildKnockout,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                label: const Text('Tạo lại nhánh',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
          ],
        ),
        if (!groupStageDone(t))
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              '⚠️ Vòng bảng có trận chưa xong — nhánh dưới đây dựng theo kết quả '
              'lúc tạo. Bấm "Tạo lại nhánh" sau khi hoàn tất vòng bảng.',
              style: TextStyle(color: AppColors.gold, fontSize: 12),
            ),
          ),
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
              aMembers: _teamMembers(s.aId),
              bMembers: _teamMembers(s.bId),
              scoreA: s.fixture.scoreA,
              scoreB: s.fixture.scoreB,
              aWon: s.winnerId != null && s.winnerId == s.aId,
              bWon: s.winnerId != null && s.winnerId == s.bId,
              decided: s.winnerId != null,
              onTap: (t.isActive && s.aId != null && s.bId != null)
                  ? () => _editKoFixture(s)
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
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rows[i].team.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    if (rows[i].team.memberNames.isNotEmpty)
                      Text(rows[i].team.memberNames.join(', '),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                  ],
                )),
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

/// Dialog đổi tên giải. Tách thành StatefulWidget để controller sống đúng
/// vòng đời của dialog (dispose ngay sau showDialog là quá sớm).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi tên giải',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Tên giải',
          hintStyle: TextStyle(color: Colors.white38),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.gold)),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child:
              const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
