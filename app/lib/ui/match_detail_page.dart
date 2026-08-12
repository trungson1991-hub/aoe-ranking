import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/match_record.dart';

// Màu quân theo empires_color (AoE).
const Map<int, Color> _slotColors = {
  1: Color(0xFF3B82F6), // xanh dương
  2: Color(0xFFEF4444), // đỏ
  3: Color(0xFF22C55E), // xanh lá
  4: Color(0xFFEAB308), // vàng
  5: Color(0xFF06B6D4), // xanh ngọc
  6: Color(0xFFEC4899), // hồng
  7: Color(0xFF9CA3AF), // xám
  8: Color(0xFFF97316), // cam
};

// Tên quân (Đế chế / AoE Rise of Rome) theo empires_type.
const Map<int, String> _civNames = {
  1: 'Assyrian', 2: 'Babylonian', 3: 'Choson', 4: 'Egyptian',
  5: 'Greek', 6: 'Hittite', 7: 'Minoan', 8: 'Persian',
  9: 'Phoenician', 10: 'Roman', 11: 'Shang', 12: 'Sumerian',
  13: 'Yamato', 14: 'Carthaginian', 15: 'Macedonian', 16: 'Palmyran',
};

class MatchDetailPage extends StatelessWidget {
  const MatchDetailPage({super.key, required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final win = r.win;
    final banner = win ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Chi tiết trận',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Banner kết quả.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [banner, banner.withOpacity(0.55)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(win ? 'CHIẾN THẮNG' : 'THẤT BẠI',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      '${r.modeLabel}  ·  ${DateFormat('dd/MM/yyyy HH:mm').format(r.dateVN)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Text('Phòng ${r.roomId}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _TeamBlock(
                title: 'Đội 1',
                players: r.red,
                viewerUuid: r.viewerUuid,
              ),
              const SizedBox(height: 12),
              _TeamBlock(
                title: 'Đội 2',
                players: r.blue,
                viewerUuid: r.viewerUuid,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.title,
    required this.players,
    required this.viewerUuid,
  });

  final String title;
  final List<PlayerStat> players;
  final String viewerUuid;

  @override
  Widget build(BuildContext context) {
    final teamWon = players.isNotEmpty && players.first.win;
    final tagColor =
        teamWon ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tagColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(teamWon ? 'THẮNG' : 'THUA',
                    style: TextStyle(
                        color: tagColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in players)
            _PlayerBlock(player: p, isViewer: p.uuid == viewerUuid),
        ],
      ),
    );
  }
}

class _PlayerBlock extends StatelessWidget {
  const _PlayerBlock({required this.player, required this.isViewer});

  final PlayerStat player;
  final bool isViewer;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final color = _slotColors[p.color] ?? const Color(0xFF64748B);
    final civ = _civNames[p.empiresType] ?? 'Quân #${p.empiresType}';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isViewer ? const Color(0xFF334155) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isViewer ? const Color(0xFFFBBF24) : Colors.white10,
          width: isViewer ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  p.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isViewer ? const Color(0xFFFBBF24) : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(civ,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              Text('Đời ${p.age}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill('⚔️', 'Giết', p.kills),
              _pill('💀', 'Mất', p.losses),
              _pill('🏰', 'Phá', p.razings),
              _pill('🪙', 'Vàng', p.gold),
              _pill('👨‍🌾', 'Dân', p.villager),
              _pill('👥', 'Dân số', p.population),
              _pill('🔬', 'C.nghệ', p.technologies),
              _pill('🗺️', 'Bản đồ', p.exploration, suffix: '%'),
              _pill('🤝', 'Bơm', p.tribute),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String icon, String label, int value, {String suffix = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '$icon $label: $value$suffix',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
