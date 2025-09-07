import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';

class PlaybackControls extends StatelessWidget {
  // FIX: This widget no longer needs its own controller.
  final EditorLoaded loadedState;
  final VoidCallback onPlayPause;

  const PlaybackControls({
    super.key,
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
            icon: const Icon(Icons.undo_rounded),
            color: loadedState.canUndo ? Colors.white : Colors.grey[700],
            onPressed: loadedState.canUndo
                ? () => context.read<EditorBloc>().add(UndoRequested())
                : null,
          ),
          IconButton(
            icon: Icon(
              loadedState.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 30,
            ),
            // FIX: Use the onPlayPause callback passed from the parent.
            onPressed: onPlayPause,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            color: loadedState.canRedo ? Colors.white : Colors.grey[700],
            onPressed: loadedState.canRedo
                ? () => context.read<EditorBloc>().add(RedoRequested())
                : null,
          ),
          const Spacer(),
          SizedBox(
            width:
                (_formatDuration(totalDuration).length +
                    3 +
                    currentTimeString.length) *
                7.0,
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
