import 'dart:math';
import 'package:flutter/material.dart';

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    super.key,
    required this.enabled,
    this.particleColor,
  });

  final bool enabled;
  final Color? particleColor;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final _random = Random(42);
  late final List<_Particle> _particles;

  static const _particleCount = 18;
  static const _connectionDistance = 120.0;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      _particleCount,
      (_) => _Particle.random(_random),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _AmbientPainter(
                particles: _particles,
                progress: _controller.value,
                color:
                    widget.particleColor ??
                    Theme.of(context).colorScheme.primary.withAlpha(0x22),
                brightness: Theme.of(context).brightness,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.size,
    required this.opacity,
  });

  double x;
  double y;
  final double speedX;
  final double speedY;
  final double size;
  final double opacity;

  factory _Particle.random(Random random) {
    return _Particle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      speedX: (random.nextDouble() - 0.5) * 0.12,
      speedY: (random.nextDouble() - 0.5) * 0.10,
      size: random.nextDouble() * 4 + 1.5,
      opacity: random.nextDouble() * 0.5 + 0.25,
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.particles,
    required this.progress,
    required this.color,
    required this.brightness,
  });

  final List<_Particle> particles;
  final double progress;
  final Color color;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = color;
    final linePaint = Paint()
      ..color = baseColor.withAlpha(brightness == Brightness.dark ? 0x0F : 0x14)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      double px = (p.x + p.speedX * progress * 60) % 1.0;
      double py = (p.y + p.speedY * progress * 60) % 1.0;
      if (px < 0) px += 1.0;
      if (py < 0) py += 1.0;

      final posX = px * size.width;
      final posY = py * size.height;

      for (int j = i + 1; j < particles.length; j++) {
        final q = particles[j];

        double qx = (q.x + q.speedX * progress * 60) % 1.0;
        double qy = (q.y + q.speedY * progress * 60) % 1.0;
        if (qx < 0) qx += 1.0;
        if (qy < 0) qy += 1.0;

        final qPosX = qx * size.width;
        final qPosY = qy * size.height;

        final dx = posX - qPosX;
        final dy = posY - qPosY;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < _AmbientBackgroundState._connectionDistance) {
          final connectionAlpha =
              (1.0 - dist / _AmbientBackgroundState._connectionDistance).clamp(
                0.0,
                1.0,
              );
          linePaint.color = baseColor.withAlpha(
            ((brightness == Brightness.dark ? 0x0F : 0x14) * connectionAlpha)
                .round(),
          );
          canvas.drawLine(Offset(posX, posY), Offset(qPosX, qPosY), linePaint);
        }
      }
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      double px = (p.x + p.speedX * progress * 60) % 1.0;
      double py = (p.y + p.speedY * progress * 60) % 1.0;
      if (px < 0) px += 1.0;
      if (py < 0) py += 1.0;

      final posX = px * size.width;
      final posY = py * size.height;

      dotPaint.color = baseColor.withAlpha((p.opacity * 155).round());
      canvas.drawCircle(Offset(posX, posY), p.size, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
