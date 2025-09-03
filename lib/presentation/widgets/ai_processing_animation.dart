// lib/presentation/widgets/ai_processing_animation.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AiProcessingAnimation extends StatelessWidget {
  const AiProcessingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    // We create a Stack of 15 stars, each with a random start delay
    return const SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Star(delay: Duration(milliseconds: 0)),
          Star(delay: Duration(milliseconds: 500)),
          Star(delay: Duration(milliseconds: 1000)),
          Star(delay: Duration(milliseconds: 1500)),
          Star(delay: Duration(milliseconds: 2000)),
          Star(delay: Duration(milliseconds: 2500)),
          Star(delay: Duration(milliseconds: 3000)),
          Star(delay: Duration(milliseconds: 3500)),
          Star(delay: Duration(milliseconds: 4000)),
          Star(delay: Duration(milliseconds: 4500)),
          Star(delay: Duration(milliseconds: 5000)),
          Star(delay: Duration(milliseconds: 5500)),
          Star(delay: Duration(milliseconds: 6000)),
          Star(delay: Duration(milliseconds: 6500)),
          Star(delay: Duration(milliseconds: 7000)),
        ],
      ),
    );
  }
}

class Star extends StatefulWidget {
  final Duration delay;
  const Star({super.key, required this.delay});

  @override
  State<Star> createState() => _StarState();
}

class _StarState extends State<Star> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();

    // Using Flutter's own AnimationController
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Define the animations using Tweens
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 20,
      ), // Fade in (20%)
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 80,
      ), // Fade out (80%)
    ]).animate(_controller);

    _scale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    final random = Random();
    _position = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(
        random.nextDouble() * 200 - 100,
        random.nextDouble() * 200 - 100,
      ),
    ).animate(_controller);

    // Start the animation after the specified delay
    Timer(widget.delay, () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds the widget on every tick of the animation
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _position.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: const Icon(Icons.star, color: Colors.white, size: 30),
            ),
          ),
        );
      },
    );
  }
}
