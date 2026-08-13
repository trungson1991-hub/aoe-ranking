import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Vẽ [child] lên nội dung phía sau bằng một chế độ hoà trộn.
///
/// Dùng cho ảnh hiệu ứng của GPlay: chúng là vòng sáng trên **nền đen đặc**
/// (không có kênh trong suốt), nên nếu vẽ thẳng sẽ để lại ô vuông đen quanh
/// avatar. Với [BlendMode.screen], màu đen không làm đổi nền còn phần sáng
/// vẫn hiện lên — đúng như hiệu ứng phát sáng mong muốn.
class BlendMask extends SingleChildRenderObjectWidget {
  const BlendMask({super.key, required this.blendMode, super.child});

  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlendMask(blendMode);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderBlendMask).blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this._blendMode);

  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
    super.paint(context, offset);
    context.canvas.restore();
  }
}
