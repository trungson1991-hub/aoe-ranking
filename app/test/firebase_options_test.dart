import 'package:aoe_ranking/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mỗi nền tảng dùng đúng appId của nó', () {
    // Bug từng gặp: mượn cấu hình web cho iOS -> SDK native thấy appId dạng
    // `:web:` là sai định dạng nên ném NSException, app crash ngay khi mở và
    // try/catch của Dart không cứu được. Ràng buộc này chặn từ gốc.
    expect(DefaultFirebaseOptions.web.appId, contains(':web:'));
    expect(DefaultFirebaseOptions.ios.appId, contains(':ios:'));
  });

  test('iOS đủ thông tin để Giải đấu chạy', () {
    const ios = DefaultFirebaseOptions.ios;
    // Phải khớp PRODUCT_BUNDLE_IDENTIFIER trong Xcode, lệch là Firebase từ chối.
    expect(ios.iosBundleId, 'com.jvbcorp.aoeRanking');
    expect(ios.projectId, 'aoe-ranking');
    // Thiếu databaseURL thì FirebaseDatabase không biết trỏ về đâu.
    expect(ios.databaseURL, isNotEmpty);
  });

  test('nền tảng chưa đăng ký trả null chứ không mượn cấu hình khác', () {
    // Test chạy trên máy chủ (macOS): không phải web, không phải iOS.
    expect(DefaultFirebaseOptions.currentPlatform, isNull);
  });
}
