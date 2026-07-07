import 'package:flutter/material.dart';

/// Genel amaçlı "shimmer" (parıltı) efekti.
/// Bu widget'a sardığın herhangi bir child'ın üzerinde soldan sağa
/// kayan bir parlaklık dalgası oluşur. Gerçek veri yerine gösterilen
/// "iskelet" (skeleton) kutularını canlandırmak için kullanılır.
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF1A2A42),
    this.highlightColor = const Color(0xFF2A3F5F),
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 0.0 -> 1.0 arası sürekli tekrar eden bir sayaç.
    // repeat() sayesinde animasyon bitince başa sarıyor, sonsuz döngü oluyor.
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    // ÖNEMLİ: AnimationController'ı her zaman dispose et, yoksa memory leak olur.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          // srcATop: gradient'i child'ın şeklinin İÇİNE boyar, dışına taşmaz.
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // _controller.value 0'dan 1'e giderken gradient'i soldan sağa kaydırıyoruz.
            final double slide = _controller.value;
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1.0 - slide * 2, 0),
              end: Alignment(1.0 - slide * 2, 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// İskelet (skeleton) kutusu: gerçek verinin yerini tutan
/// basit, düz renkli bir dikdörtgen/daire.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 6,
    this.color = const Color(0xFF1A2A42),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
