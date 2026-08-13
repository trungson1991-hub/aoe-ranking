import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../leaderboard/models/leaderboard.dart';
import '../logic/tournament_edit.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../widgets/member_picker.dart';

/// Sửa giải sau khi đã tạo: tên giải, tiền thưởng, tên đội, thành viên,
/// chuyển đội sang bảng khác. Trang này chỉ mở được sau khi qua PIN
/// (từ trang chi tiết giải).
class TournamentEditPage extends StatefulWidget {
  const TournamentEditPage({
    super.key,
    required this.tournament,
    required this.roster,
    required this.service,
  });

  final Tournament tournament;
  final List<Member> roster;
  final TournamentService service;

  @override
  State<TournamentEditPage> createState() => _TournamentEditPageState();
}

class _EditTeam {
  _EditTeam(this.id, String name, this.memberUuids, this.groupName) {
    nameCtrl.text = name;
  }

  final String id;
  final TextEditingController nameCtrl = TextEditingController();
  List<String> memberUuids;
  String? groupName; // tên bảng đang thuộc (null với giải 1 bảng vòng tròn)

  void dispose() => nameCtrl.dispose();
}

class _TournamentEditPageState extends State<TournamentEditPage> {
  late final List<_EditTeam> _teams;
  final _name = TextEditingController();
  // Tiền thưởng theo hạng: nhất / nhì / ba.
  final List<TextEditingController> _prizes =
      List.generate(3, (_) => TextEditingController());
  bool _saving = false;

  Tournament get t => widget.tournament;
  bool get _hasGroups => t.structure == kStructureGroupsKnockout;
  int get _teamSize => int.parse(t.format.substring(0, 1));

  @override
  void initState() {
    super.initState();
    _name.text = t.name;
    for (var i = 0; i < 3; i++) {
      final v = i < t.prizes.length ? t.prizes[i] : 0;
      if (v > 0) _prizes[i].text = '$v';
    }
    _teams = [
      for (final team in t.teams)
        _EditTeam(team.id, team.name, [...team.memberUuids],
            _hasGroups ? _groupOf(team.id) : null),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _prizes) {
      c.dispose();
    }
    for (final e in _teams) {
      e.dispose();
    }
    super.dispose();
  }

  String? _groupOf(String teamId) {
    for (final g in t.groups) {
      if (g.teamIds.contains(teamId)) return g.name;
    }
    return t.groups.isNotEmpty ? t.groups.first.name : null;
  }

  // Tên hiển thị: ưu tiên roster (mới nhất), fallback tên đã lưu trong giải.
  String _nameOf(String uuid) {
    for (final m in widget.roster) {
      if (m.userUuid == uuid) return m.name;
    }
    for (final team in t.teams) {
      final i = team.memberUuids.indexOf(uuid);
      if (i >= 0 && i < team.memberNames.length) return team.memberNames[i];
    }
    return '?';
  }

  Set<String> _usedExcept(_EditTeam self) {
    final s = <String>{};
    for (final e in _teams) {
      if (e != self) s.addAll(e.memberUuids);
    }
    return s;
  }

  Future<void> _pickMembers(_EditTeam team) async {
    final result = await showMemberPicker(
      context,
      roster: widget.roster,
      teamSize: _teamSize,
      initial: team.memberUuids,
      taken: _usedExcept(team),
    );
    if (result != null) setState(() => team.memberUuids = result);
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Chưa nhập tên giải';
    final allUuids = <String>{};
    for (final e in _teams) {
      if (e.nameCtrl.text.trim().isEmpty) return 'Có đội chưa có tên';
      if (e.memberUuids.length != _teamSize) {
        return 'Đội "${e.nameCtrl.text.trim()}" cần đúng $_teamSize thành viên';
      }
      for (final u in e.memberUuids) {
        if (!allUuids.add(u)) return 'Một người bị xếp vào 2 đội';
      }
    }
    if (_hasGroups) {
      for (final g in t.groups) {
        final count = _teams.where((e) => e.groupName == g.name).length;
        if (count < 2) return '${g.name} cần ít nhất 2 đội';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final newTeams = [
      for (final e in _teams)
        TournTeam(
          id: e.id,
          name: e.nameCtrl.text.trim(),
          memberUuids: e.memberUuids,
          memberNames: e.memberUuids.map(_nameOf).toList(),
        ),
    ];
    final newGroups = _hasGroups
        ? [
            for (final g in t.groups)
              GroupDef(name: g.name, teamIds: [
                for (final e in _teams)
                  if (e.groupName == g.name) e.id,
              ]),
          ]
        : t.groups;

    // Đổi bảng -> lịch bảng liên quan bị tạo lại, cảnh báo trước khi lưu.
    final changed = changedGroupStages(t, newGroups);
    if (changed.isNotEmpty) {
      final koWarning =
          t.koFixtures.isNotEmpty ? '\nNhánh loại trực tiếp cũng bị xoá.' : '';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tạo lại lịch?',
              style: TextStyle(color: Colors.white)),
          content: Text(
            'Đội đã đổi bảng. Lịch của ${changed.join(', ')} sẽ được tạo lại '
            'và KẾT QUẢ các trận trong bảng đó bị xoá.$koWarning',
            style: const TextStyle(color: Colors.white70),
          ),
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
      if (ok != true) return;
    }

    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final updated = applyTeamEdits(t, teams: newTeams, groups: newGroups)
          .copyWith(
        name: _name.text.trim(),
        prizes: [for (final c in _prizes) parseMoney(c.text)],
      );
      await widget.service.save(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sửa đội & bảng',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _name,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Tên giải'),
              ),
              const SizedBox(height: 14),
              const Text('Tiền thưởng (đ) — để trống nếu không có',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _prizes[i],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration: _dec(const ['🥇 Nhất', '🥈 Nhì', '🥉 Ba'][i]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Đổi tên đội / thành viên: giữ nguyên lịch và kết quả. '
                'Chuyển đội sang bảng khác: lịch bảng liên quan được tạo lại.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final e in _teams) _teamCard(e),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Lưu thay đổi',
                        style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.gold)),
      );

  Widget _teamCard(_EditTeam e) {
    final names = e.memberUuids.map(_nameOf).join(', ');
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: e.nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Tên đội'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  names.isEmpty ? 'Chưa chọn thành viên' : '👤 $names',
                  style: TextStyle(
                      color: names.isEmpty ? Colors.white38 : Colors.white70,
                      fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => _pickMembers(e),
                child: Text('Chọn ($_teamSize)',
                    style: const TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
          if (_hasGroups)
            Row(
              children: [
                const Text('Bảng:',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 10),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: e.groupName,
                    isDense: true,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (v) => setState(() => e.groupName = v),
                    items: [
                      for (final g in t.groups)
                        DropdownMenuItem(value: g.name, child: Text(g.name)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
