import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Displays the main video player viewport.
class VideoViewport extends StatelessWidget {
  final VideoPlayerController? controller;

  const VideoViewport({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      color: Colors.black,
      child: Center(
        child: controller != null && controller!.value.isInitialized
            ? FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller!.value.size.height,
                  child: VideoPlayer(controller!),
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
