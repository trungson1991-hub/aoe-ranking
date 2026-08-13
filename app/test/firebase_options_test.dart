import 'package:aoe_ranking/firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nền tảng native không được mượn cấu hình web', () {
    // Test chạy trên máy chủ (không phải web) -> phải là null.
    // Nếu ai đó trả tạm `web` cho iOS/Android, SDK native sẽ ném NSException
    // lúc initializeApp và app crash ngay khi mở — Dart try/catch không cứu
    // được, nên phải chặn ở đây.
    expect(kIsWeb, isFalse, reason: 'test này chỉ có nghĩa khi chạy native');
    expect(DefaultFirebaseOptions.currentPlatform, isNull);
  });

  test('cấu hình web vẫn là appId dạng web', () {
    expect(DefaultFirebaseOptions.web.appId, contains(':web:'));
    expect(DefaultFirebaseOptions.web.projectId, 'aoe-ranking');
  });
}
