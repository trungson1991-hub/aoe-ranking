import 'package:flutter/material.dart';

/// Hộp thoại nhập PIN của giải. Trả về true nếu khớp [expectedPin].
/// So sánh sau khi trim 2 phía (PIN lưu khi tạo giải đã được trim).
Future<bool> askPin(BuildContext context, String expectedPin) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PinDialog(expectedPin: expectedPin),
  );
  if (ok != true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN sai hoặc đã huỷ')),
    );
  }
  return ok == true;
}

/// Tách thành StatefulWidget để controller sống đúng vòng đời của dialog.
/// Dispose ngay sau `showDialog` là quá sớm: dialog còn đang chạy animation
/// đóng và ô nhập vẫn đang nghe controller.
class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.expectedPin});

  final String expectedPin;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // PIN rỗng (dữ liệu cũ / sửa tay trên DB) thì KHÔNG bao giờ khớp — nếu
  // không, bấm OK với ô trống là mở khoá được mọi thao tác.
  bool get _matches =>
      widget.expectedPin.trim().isNotEmpty &&
      _ctrl.text.trim() == widget.expectedPin.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhập PIN của giải',
          style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _ctrl,
        obscureText: true,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: 'PIN'),
        onSubmitted: (_) => Navigator.pop(context, _matches),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ')),
        TextButton(
            onPressed: () => Navigator.pop(context, _matches),
            child: const Text('OK')),
      ],
    );
  }
}
