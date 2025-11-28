import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Renders video transitions by blending two video controllers
/// based on transition type and progress (0.0 to 1.0)
class TransitionRenderer extends StatelessWidget {
  final VideoPlayerController? activeController;
  final VideoPlayerController? incomingController;
  final String? transitionType;
  final double progress; // 0.0 = show active, 1.0 = show incoming

  const TransitionRenderer({
    super.key,
    required this.activeController,
    required this.incomingController,
    required this.transitionType,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // No transition - show only active controller
    if (transitionType == null ||
        incomingController == null ||
        !incomingController!.value.isInitialized ||
        progress <= 0.0) {
      return _buildSingleVideo(activeController);
    }

    // Transition complete - show only incoming controller
    if (progress >= 1.0) {
      return _buildSingleVideo(incomingController);
    }

    // During transition - blend both controllers
    return _buildTransition();
  }

  Widget _buildSingleVideo(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final double videoRatio = controller.value.aspectRatio;
    return AspectRatio(
      aspectRatio: videoRatio,
      child: VideoPlayer(controller),
    );
  }

  Widget _buildTransition() {
    final activeRatio = activeController?.value.aspectRatio ?? 16 / 9;
    final incomingRatio = incomingController?.value.aspectRatio ?? 16 / 9;

    switch (transitionType) {
      case 'fade':
        return _buildFadeTransition(activeRatio, incomingRatio);

      case 'slideleft':
        return _buildSlideTransition(activeRatio, incomingRatio, toLeft: true);

      case 'slideright':
        return _buildSlideTransition(activeRatio, incomingRatio, toLeft: false);

      case 'wipeleft':
        return _buildWipeTransition(activeRatio, incomingRatio);

      case 'circleopen':
        return _buildCircleTransition(activeRatio, incomingRatio);

      default:
        return _buildFadeTransition(activeRatio, incomingRatio);
    }
  }

  // FADE: Cross-dissolve between clips
  Widget _buildFadeTransition(double activeRatio, double incomingRatio) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video (fading out)
        AspectRatio(
          aspectRatio: activeRatio,
          child: Opacity(
            opacity: 1.0 - progress,
            child: VideoPlayer(activeController!),
          ),
        ),
        // Incoming video (fading in)
        AspectRatio(
          aspectRatio: incomingRatio,
          child: Opacity(
            opacity: progress,
            child: VideoPlayer(incomingController!),
          ),
        ),
      ],
    );
  }

  // SLIDE: Push transition (old slides out, new slides in)
  Widget _buildSlideTransition(
    double activeRatio,
    double incomingRatio, {
    required bool toLeft,
  }) {
    final offset = toLeft ? -progress : progress;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video (sliding out)
        ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: FractionalTranslation(
              translation: Offset(offset, 0),
              child: AspectRatio(
                aspectRatio: activeRatio,
                child: VideoPlayer(activeController!),
              ),
            ),
          ),
        ),
        // Incoming video (sliding in from opposite direction)
        ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: FractionalTranslation(
              translation: Offset(toLeft ? (1 - progress) : (-1 + progress), 0),
              child: AspectRatio(
                aspectRatio: incomingRatio,
                child: VideoPlayer(incomingController!),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // WIPE: Hard-edge wipe from right to left
  Widget _buildWipeTransition(double activeRatio, double incomingRatio) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video (full background)
        AspectRatio(
          aspectRatio: activeRatio,
          child: VideoPlayer(activeController!),
        ),
        // Incoming video (wiping in with a hard edge)
        ClipRect(
          clipper: _WipeClipper(progress),
          child: AspectRatio(
            aspectRatio: incomingRatio,
            child: VideoPlayer(incomingController!),
          ),
        ),
      ],
    );
  }

  // CIRCLE: Expanding circle reveal
  Widget _buildCircleTransition(double activeRatio, double incomingRatio) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video (background)
        AspectRatio(
          aspectRatio: activeRatio,
          child: VideoPlayer(activeController!),
        ),
        // Incoming video (circular reveal)
        ClipPath(
          clipper: _CircleClipper(progress),
          child: AspectRatio(
            aspectRatio: incomingRatio,
            child: VideoPlayer(incomingController!),
          ),
        ),
      ],
    );
  }
}

// Custom clipper for wipe transition
class _WipeClipper extends CustomClipper<Rect> {
  final double progress;
  _WipeClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      0,
      0,
      size.width * progress,
      size.height,
    );
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.progress != progress;
}

// Custom clipper for circle transition
class _CircleClipper extends CustomClipper<Path> {
  final double progress;
  _CircleClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide;
    final radius = maxRadius * progress;

    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(_CircleClipper oldClipper) => oldClipper.progress != progress;
}
