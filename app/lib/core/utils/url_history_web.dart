import 'package:web/web.dart' as web;

/// Thay URL trên thanh địa chỉ mà không reload trang.
void replaceUrl(String url) =>
    web.window.history.replaceState(null, '', url);
