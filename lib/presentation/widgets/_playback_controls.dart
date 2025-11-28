import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';

class PlaybackControls extends StatelessWidget {
  final EditorLoaded loadedState;
  final VoidCallback onPlayPause;
  final ValueNotifier<bool> isPlayingNotifier;
  final ValueNotifier<Duration> positionNotifier;

  const PlaybackControls({
    super.key,
    required this.loadedState,
    required this.onPlayPause,
    required this.isPlayingNotifier,
    required this.positionNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 22, 22, 22),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // 1. Time Display
          ValueListenableBuilder<Duration>(
            valueListenable: positionNotifier,
            builder: (context, position, child) {
              return Text(
                "${_formatDuration(position)} / ${_formatDuration(loadedState.videoDuration)}",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              );
            },
          ),

          const Spacer(),

          // 2. Play/Pause
          ValueListenableBuilder<bool>(
            valueListenable: isPlayingNotifier,
            builder: (context, isPlaying, child) {
              return IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: onPlayPause,
              );
            },
          ),

          const Spacer(),

          // 3. Undo / Redo Buttons (CapCut Style: Right side)
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.undo,
                  color: loadedState.canUndo ? Colors.white : Colors.white24,
                  size: 20,
                ),
                onPressed: loadedState.canUndo
                    ? () => context.read<EditorBloc>().add(UndoRequested())
                    : null,
              ),
              IconButton(
                icon: Icon(
                  Icons.redo,
                  color: loadedState.canRedo ? Colors.white : Colors.white24,
                  size: 20,
                ),
                onPressed: loadedState.canRedo
                    ? () => context.read<EditorBloc>().add(RedoRequested())
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}
