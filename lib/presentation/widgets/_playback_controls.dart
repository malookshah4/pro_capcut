import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';

class PlaybackControls extends StatelessWidget {
  final EditorLoaded loadedState;
  final VoidCallback onPlayPause;
  // NEW: Receive notifiers from the coordinator
  final ValueListenable<bool> isPlayingNotifier;
  final ValueListenable<Duration> positionNotifier;

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
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // This Text widget listens to the position notifier for efficient updates
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
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            color: loadedState.canUndo ? Colors.white : Colors.grey[700],
            onPressed: loadedState.canUndo
                ? () => context.read<EditorBloc>().add(UndoRequested())
                : null,
          ),
          // The play/pause button listens to the isPlaying notifier
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
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            color: loadedState.canRedo ? Colors.white : Colors.grey[700],
            onPressed: loadedState.canRedo
                ? () => context.read<EditorBloc>().add(RedoRequested())
                : null,
          ),
          const Spacer(),
          // Placeholder to balance the layout
          SizedBox(
            width:
                (_formatDuration(loadedState.videoDuration).length + 3) * 14.0,
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
