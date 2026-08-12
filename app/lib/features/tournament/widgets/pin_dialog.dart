import 'package:flutter/material.dart';

/// Hộp thoại nhập PIN của giải. Trả về true nếu khớp [expectedPin].
/// So sánh sau khi trim 2 phía (PIN lưu khi tạo giải đã được trim).
Future<bool> askPin(BuildContext context, String expectedPin) async {
  final ctrl = TextEditingController();
  bool matches() => ctrl.text.trim() == expectedPin.trim();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nhập PIN của giải',
          style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: ctrl,
        obscureText: true,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: 'PIN'),
        onSubmitted: (_) => Navigator.pop(ctx, matches()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, matches()),
            child: const Text('OK')),
      ],
    ),
  );
  ctrl.dispose();
  if (ok != true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN sai hoặc đã huỷ')),
    );
  }
  return ok == true;
}
