// lib/presentation/widgets/exporting_screen.dart
import 'package:flutter/material.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:video_player/video_player.dart';

class ExportingScreen extends StatelessWidget {
  final EditorProcessing processingState;
  final VideoPlayerController? previewController; // To show a preview

  const ExportingScreen({
    super.key,
    required this.processingState,
    required this.previewController,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = (processingState.progress * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            const Text(
              "Exporting video...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please don't close the app or lock your screen.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 40),
            // Video Preview Container
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[900],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    if (previewController != null &&
                        previewController!.value.isInitialized)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: previewController!.value.size.width,
                          height: previewController!.value.size.height,
                          child: VideoPlayer(previewController!),
                        ),
                      ),
                    // Dimming overlay
                    Container(color: Colors.black.withOpacity(0.4)),
                    // Percentage Text
                    Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black54),
                        ],
                      ),
                    ),
                    // Progress bar at the top of the preview
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: processingState.progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
