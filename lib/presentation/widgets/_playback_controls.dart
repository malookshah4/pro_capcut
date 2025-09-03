import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:video_player/video_player.dart';

/// Displays the playback controls (play/pause, time, undo/redo).
class PlaybackControls extends StatelessWidget {
  final VideoPlayerController? controller;
  final EditorLoaded loadedState;
  // --- ADDED: Callback for play/pause logic ---
  final VoidCallback onPlayPause;

  const PlaybackControls({
    super.key,
    required this.controller,
    required this.loadedState,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final currentTimeString = _formatDuration(loadedState.videoPosition);
    final totalDuration = loadedState.videoDuration;

    return Container(
      color: const Color.fromARGB(255, 22, 22, 22),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Text(
            "$currentTimeString / ${_formatDuration(totalDuration)}",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.undo),
            color: loadedState.canUndo ? Colors.white : Colors.grey[700],
            onPressed: loadedState.canUndo
                ? () => context.read<EditorBloc>().add(UndoRequested())
                : null,
          ),
          IconButton(
            icon: Icon(
              loadedState.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: Colors.white,
              size: 40,
            ),
            // --- MODIFIED: Use the passed-in callback ---
            onPressed: onPlayPause,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            color: loadedState.canRedo ? Colors.white : Colors.grey[700],
            onPressed: loadedState.canRedo
                ? () => context.read<EditorBloc>().add(RedoRequested())
                : null,
          ),
          const Spacer(),
          SizedBox(
            width:
                (_formatDuration(totalDuration).length * 2 +
                    currentTimeString.length) *
                4.0,
          ),
        ],
      ),
    );
  }
}

/// Formats a Duration into a mm:ss string.
String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}
