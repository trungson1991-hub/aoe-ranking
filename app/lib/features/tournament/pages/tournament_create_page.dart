import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../leaderboard/models/leaderboard.dart';
import '../data/fun_team_names.dart';
import '../logic/group_assign.dart';
import '../logic/round_robin.dart';
import '../models/tournament.dart';
import '../services/tournament_service.dart';
import '../widgets/member_picker.dart';

class _TeamDraft {
  _TeamDraft(String initialName) {
    name.text = initialName;
  }

  final TextEditingController name = TextEditingController();
  List<String> memberUuids = [];
  int? group; // bảng đã chọn (0-based); null = tự chia

  void dispose() => name.dispose();
}

class TournamentCreatePage extends StatefulWidget {
  const TournamentCreatePage(
      {super.key, required this.roster, required this.service});

  final List<Member> roster;
  final TournamentService service;

  @override
  State<TournamentCreatePage> createState() => _TournamentCreatePageState();
}

class _TournamentCreatePageState extends State<TournamentCreatePage> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  // Tiền thưởng theo hạng: nhất / nhì / ba (tuỳ chọn).
  final List<TextEditingController> _prizes =
      List.generate(3, (_) => TextEditingController());
  String _format = '1v1';
  int _firstTo = 1;
  String _structure = kStructureRoundRobin;
  int _numGroups = 2;
  int _advance = 1;
  final List<_TeamDraft> _teams = [];
  bool _saving = false;

  // Điều khiển animation thêm/xoá đội trong danh sách.
  final _teamListKey = GlobalKey<AnimatedListState>();
  static const _insertDuration = Duration(milliseconds: 350);
  static const _removeDuration = Duration(milliseconds: 220);

  int get _teamSize => int.parse(_format.substring(0, 1));

  @override
  void initState() {
    super.initState();
    // 2 đội khởi điểm, mỗi đội 1 tên vui sẵn (sửa được).
    _teams.add(_newDraft());
    _teams.add(_newDraft());
  }

  _TeamDraft _newDraft() => _TeamDraft(randomFunTeamName(
      exclude: _teams.map((t) => t.name.text).toSet()));

  // Thêm đội vào ĐẦU danh sách (ngay dưới nút "Thêm đội", khỏi phải cuộn
  // xuống cuối) với animation trượt-hiện cho dễ nhận biết.
  void _addTeamAtTop() {
    setState(() => _teams.insert(0, _newDraft()));
    _teamListKey.currentState?.insertItem(0, duration: _insertDuration);
  }

  void _removeTeam(int i) {
    final draft = _teams.removeAt(i);
    setState(() {});
    _teamListKey.currentState?.removeItem(
      i,
      (context, anim) => SizeTransition(
        sizeFactor: anim,
        child: FadeTransition(
          opacity: anim,
          child: _teamCard(draft, i, removable: false),
        ),
      ),
      duration: _removeDuration,
    );
    // Card đang chạy animation biến mất vẫn dùng controller -> dispose sau.
    Future.delayed(const Duration(milliseconds: 500), draft.dispose);
  }

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    for (final c in _prizes) {
      c.dispose();
    }
    for (final t in _teams) {
      t.dispose();
    }
    super.dispose();
  }

  String _nameOf(String uuid) {
    for (final m in widget.roster) {
      if (m.userUuid == uuid) return m.name;
    }
    return '?';
  }

  // Các uuid đã được chọn ở đội khác (để không trùng).
  Set<String> _usedExcept(_TeamDraft self) {
    final s = <String>{};
    for (final t in _teams) {
      if (t == self) continue;
      s.addAll(t.memberUuids);
    }
    return s;
  }

  Future<void> _pickMembers(_TeamDraft team) async {
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
    if (_pin.text.trim().isEmpty) return 'Chưa đặt PIN cho giải';
    if (_teams.length < 2) return 'Cần ít nhất 2 đội';
    final allUuids = <String>{};
    for (var i = 0; i < _teams.length; i++) {
      final t = _teams[i];
      if (t.name.text.trim().isEmpty) return 'Đội ${i + 1} chưa có tên';
      if (t.memberUuids.length != _teamSize) {
        return 'Đội "${t.name.text.trim()}" cần đúng $_teamSize thành viên';
      }
      for (final u in t.memberUuids) {
        if (!allUuids.add(u)) return 'Một người bị xếp vào 2 đội';
      }
    }
    if (_structure == kStructureGroupsKnockout) {
      if (_teams.length < _numGroups * 2) {
        return 'Cần ít nhất ${_numGroups * 2} đội cho $_numGroups bảng';
      }
      // Sau khi chia (kể cả đội chọn bảng tay), mỗi bảng phải có >= 2 đội.
      final buckets = distributeTeams(
          [for (final t in _teams) t.group], _numGroups);
      for (var g = 0; g < buckets.length; g++) {
        if (buckets[g].length < 2) {
          return 'Bảng ${String.fromCharCode(65 + g)} cần ít nhất 2 đội '
              '(đổi lựa chọn bảng của các đội)';
        }
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
    setState(() => _saving = true);
    try {
      final teams = <TournTeam>[
        for (var i = 0; i < _teams.length; i++)
          TournTeam(
            id: 't$i',
            name: _teams[i].name.text.trim(),
            memberUuids: _teams[i].memberUuids,
            memberNames: _teams[i].memberUuids.map(_nameOf).toList(),
          ),
      ];
      final teamIds = teams.map((e) => e.id).toList();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      List<GroupDef> groups;
      List<Fixture> gfx;
      var advance = 1;
      if (_structure == kStructureGroupsKnockout) {
        advance = _advance;
        // Đội đã chọn bảng giữ nguyên; đội "tự chia" vào bảng ít đội nhất.
        final buckets = distributeTeams(
            [for (final t in _teams) t.group], _numGroups);
        groups = [];
        gfx = [];
        for (var i = 0; i < _numGroups; i++) {
          final name = 'Bảng ${String.fromCharCode(65 + i)}';
          final ids = [for (final idx in buckets[i]) teamIds[idx]];
          groups.add(GroupDef(name: name, teamIds: ids));
          gfx.addAll(generateRoundRobin(ids, stage: name));
        }
      } else {
        groups = [GroupDef(name: 'Vòng tròn', teamIds: teamIds)];
        gfx = generateRoundRobin(teamIds, stage: 'Vòng tròn');
      }

      await widget.service.create((id) => Tournament(
            id: id,
            name: _name.text.trim(),
            pin: _pin.text.trim(),
            format: _format,
            firstTo: _firstTo,
            structure: _structure,
            advancePerGroup: advance,
            createdAt: now,
            prizes: [for (final c in _prizes) parseMoney(c.text)],
            teams: teams,
            groups: groups,
            groupFixtures: gfx,
            koFixtures: const [],
          ));
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
        title: const Text('Tạo giải',
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
              TextField(
                controller: _pin,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('PIN của giải (dùng để nhập kết quả / xoá)'),
              ),
              const SizedBox(height: 14),
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
                        decoration: _dec(
                            const ['🥇 Nhất (đ)', '🥈 Nhì (đ)', '🥉 Ba (đ)'][i]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _dropdown<String>(
                      label: 'Thể loại',
                      value: _format,
                      items: const ['1v1', '2v2', '3v3', '4v4'],
                      itemLabel: (v) => v,
                      onChanged: (v) => setState(() {
                        _format = v!;
                        for (final t in _teams) {
                          t.memberUuids = []; // đổi cỡ đội -> xoá chọn cũ
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdown<int>(
                      label: 'Chạm (first-to)',
                      value: _firstTo,
                      items: List.generate(9, (i) => i + 1),
                      itemLabel: (v) => 'Chạm $v',
                      onChanged: (v) => setState(() => _firstTo = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _dropdown<String>(
                label: 'Thể thức thi đấu',
                value: _structure,
                items: const [kStructureRoundRobin, kStructureGroupsKnockout],
                itemLabel: (v) => v == kStructureRoundRobin
                    ? '1 bảng vòng tròn'
                    : 'Nhiều bảng + loại trực tiếp',
                onChanged: (v) => setState(() => _structure = v!),
              ),
              if (_structure == kStructureGroupsKnockout) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dropdown<int>(
                        label: 'Số bảng',
                        value: _numGroups,
                        items: const [2, 3, 4],
                        itemLabel: (v) => '$v bảng',
                        onChanged: (v) => setState(() {
                          _numGroups = v!;
                          // Bớt bảng -> lựa chọn vượt số bảng trở về "tự chia".
                          for (final t in _teams) {
                            if ((t.group ?? -1) >= v) t.group = null;
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdown<int>(
                        label: 'Đi tiếp mỗi bảng',
                        value: _advance,
                        items: const [1, 2],
                        itemLabel: (v) => '$v đội',
                        onChanged: (v) => setState(() => _advance = v!),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('Các đội',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addTeamAtTop,
                    icon: const Icon(Icons.add, color: AppColors.gold),
                    label: const Text('Thêm đội',
                        style: TextStyle(color: AppColors.gold)),
                  ),
                ],
              ),
              AnimatedList(
                key: _teamListKey,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                initialItemCount: _teams.length,
                itemBuilder: (context, i, anim) => SizeTransition(
                  sizeFactor:
                      CurvedAnimation(parent: anim, curve: Curves.easeOut),
                  child: FadeTransition(
                    opacity: anim,
                    child: _teamCard(_teams[i], i),
                  ),
                ),
              ),
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
                    : const Text('Tạo giải',
                        style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhiều bảng: các đội chia đều vào bảng, đá vòng tròn; xong vòng bảng thì mở nhánh loại trực tiếp.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamCard(_TeamDraft t, int i, {bool removable = true}) {
    final names = t.memberUuids.map(_nameOf).join(', ');
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: t.name,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Tên đội ${i + 1}'),
                ),
              ),
              if (removable && _teams.length > 2)
                IconButton(
                  onPressed: () => _removeTeam(i),
                  icon: const Icon(Icons.delete_outline, color: Colors.white38),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  names.isEmpty ? 'Chưa chọn thành viên' : names,
                  style: TextStyle(
                      color: names.isEmpty ? Colors.white38 : Colors.white70,
                      fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => _pickMembers(t),
                child: Text('Chọn ($_teamSize)',
                    style: const TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
          if (_structure == kStructureGroupsKnockout) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Bảng:',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 10),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: t.group,
                    isDense: true,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (v) => setState(() => t.group = v),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Tự chia')),
                      for (var g = 0; g < _numGroups; g++)
                        DropdownMenuItem<int?>(
                            value: g,
                            child:
                                Text('Bảng ${String.fromCharCode(65 + g)}')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
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

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: _dec(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: Colors.white),
          onChanged: onChanged,
          items: [
            for (final it in items)
              DropdownMenuItem(value: it, child: Text(itemLabel(it))),
          ],
        ),
      ),
    );
  }
}
