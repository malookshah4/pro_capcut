import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:video_player/video_player.dart';

class VideoViewport extends StatelessWidget {
  final VideoPlayerController? controller;

  const VideoViewport({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Watch state to rebuild when ratio changes
    final state = context.watch<EditorBloc>().state;

    double? canvasRatio;
    if (state is EditorLoaded) {
      canvasRatio = state.project.canvasAspectRatio;
    }

    return Container(
      // The overall viewport area height (adjust as needed for your layout)
      height: MediaQuery.of(context).size.height * 0.450,
      width: double.infinity,
      color: Colors.black, // Background for letterboxing
      child: Center(
        child: (controller != null && controller!.value.isInitialized)
            ? _buildPlayer(canvasRatio, controller!)
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildPlayer(double? canvasRatio, VideoPlayerController controller) {
    final videoRatio = controller.value.aspectRatio;

    // 1. "Fit" Mode (Original) - No fixed canvas
    if (canvasRatio == null) {
      return AspectRatio(
        aspectRatio: videoRatio,
        child: VideoPlayer(controller),
      );
    }

    // 2. "Canvas" Mode (Fixed Ratio)
    // We force the container to the selected ratio (e.g. 9:16)
    // The video is then contained inside it.
    return AspectRatio(
      aspectRatio: canvasRatio,
      child: Container(
        color: Colors.black, // The black bars
        child: Center(
          child: AspectRatio(
            aspectRatio: videoRatio,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
