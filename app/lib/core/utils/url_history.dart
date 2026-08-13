/// Thao tác URL trình duyệt (chỉ có tác dụng trên web; nơi khác là no-op).
library;

export 'url_history_stub.dart'
    if (dart.library.js_interop) 'url_history_web.dart';
