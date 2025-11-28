import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/text_clip.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/widgets/speed_control_sheet.dart';
import 'package:pro_capcut/presentation/widgets/text_editor_sheet.dart';
import 'package:pro_capcut/presentation/widgets/volume_control_sheet.dart';

const double kToolbarHeight = 80.0;

// The Main Toolbar Widget
class MainToolbar extends StatelessWidget {
  final int currentIndex;
  final Function(int index) onTap;
  const MainToolbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: const Color.fromARGB(255, 22, 22, 22),
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(EvaIcons.edit),
            label: 'Edit',
          ), // 0
          BottomNavigationBarItem(
            icon: Icon(EvaIcons.music),
            label: 'Audio',
          ), // 1
          BottomNavigationBarItem(
            icon: Icon(Icons.text_fields),
            label: 'Text',
          ), // 2
          BottomNavigationBarItem(
            icon: Icon(Icons.aspect_ratio),
            label: 'Format',
          ), // 3 (NEW)
          BottomNavigationBarItem(
            icon: Icon(Icons.waves),
            label: 'Stabilize',
          ), // 4
          BottomNavigationBarItem(
            icon: Icon(Icons.layers),
            label: 'Overlay',
          ), // 5
        ],
      ),
    );
  }
}

class EditToolbar extends StatelessWidget {
  const EditToolbar({super.key});
  @override
  Widget build(BuildContext context) {
    final EditorLoaded state =
        context.watch<EditorBloc>().state as EditorLoaded;
    final Duration splitAt = state.videoPosition;
    final String? trackId = state.selectedTrackId;
    final String? clipId = state.selectedClipId;

    // Get current values for initial sheet state
    double currentSpeed = 1.0;
    double currentVolume = 1.0;

    if (trackId != null && clipId != null) {
      try {
        final track = state.project.tracks.firstWhere((t) => t.id == trackId);
        final clip = track.clips.firstWhere((c) => c.id == clipId);

        // FIX: Check for BOTH Video and Audio clips
        if (clip is VideoClip) {
          currentSpeed = clip.speed;
          currentVolume = clip.volume;
        } else if (clip is AudioClip) {
          // Audio clips generally don't support speed in this basic implementation yet,
          // but they definitely support volume.
          currentVolume = clip.volume;
        }
      } catch (e) {}
    }

    return SizedBox(
      height: kToolbarHeight,
      child: BottomAppBar(
        color: const Color.fromARGB(255, 22, 22, 22),
        padding: EdgeInsets.zero,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () =>
                  context.read<EditorBloc>().add(const ClipTapped()),
            ),
            const VerticalDivider(
              color: Colors.white30,
              indent: 16,
              endIndent: 16,
              width: 1,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolbarItem(
                    icon: Icons.cut,
                    label: 'Split',
                    onTap: () {
                      context.read<EditorBloc>().add(
                        ClipSplitRequested(splitAt: splitAt),
                      );
                    },
                  ),
                  _buildToolbarItem(
                    icon: Icons.speed,
                    label: 'Speed',
                    onTap: () async {
                      final result = await showModalBottomSheet<double>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SpeedControlSheet(
                          initialSpeed: currentSpeed,
                          originalDuration: const Duration(
                            minutes: 1,
                          ), // Dummy duration
                        ),
                      );
                      if (result != null && context.mounted) {
                        context.read<EditorBloc>().add(
                          ClipSpeedChanged(result),
                        );
                      }
                    },
                  ),
                  _buildToolbarItem(
                    icon: Icons.volume_up_outlined,
                    label: 'Volume',
                    onTap: () async {
                      final result = await showModalBottomSheet<double>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            VolumeControlSheet(initialVolume: currentVolume),
                      );
                      // Only update if user clicked Check (result is not null)
                      if (result != null && context.mounted) {
                        context.read<EditorBloc>().add(
                          ClipVolumeChanged(result),
                        );
                      }
                    },
                  ),
                  _buildToolbarItem(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onTap: () {
                      if (trackId != null && clipId != null) {
                        context.read<EditorBloc>().add(
                          ClipDeleted(trackId: trackId, clipId: clipId),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW: Toolbar for Text Clips ---
class TextToolbar extends StatelessWidget {
  final TextClip clip;
  final String trackId;

  const TextToolbar({super.key, required this.clip, required this.trackId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: BottomAppBar(
        color: const Color.fromARGB(255, 22, 22, 22),
        padding: EdgeInsets.zero,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () =>
                  context.read<EditorBloc>().add(const ClipTapped()),
            ),
            const VerticalDivider(
              color: Colors.white30,
              indent: 16,
              endIndent: 16,
              width: 1,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // EDIT BUTTON
                  _buildToolbarItem(
                    icon: Icons.keyboard,
                    label: 'Style',
                    onTap: () async {
                      // Open the Text Editor Sheet with current values
                      final result =
                          await showModalBottomSheet<TextEditorResult>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => TextEditorSheet(
                              initialText: clip.text,
                              initialStyle: clip.style,
                            ),
                          );

                      if (result != null && context.mounted) {
                        context.read<EditorBloc>().add(
                          ClipTextUpdated(
                            trackId: trackId,
                            clipId: clip.id,
                            text: result.text,
                            style: result.style,
                          ),
                        );
                      }
                    },
                  ),
                  _buildToolbarItem(
                    icon: Icons.cut,
                    label: 'Split',
                    onTap: () {
                      final state =
                          context.read<EditorBloc>().state as EditorLoaded;
                      context.read<EditorBloc>().add(
                        ClipSplitRequested(splitAt: state.videoPosition),
                      );
                    },
                  ),
                  _buildToolbarItem(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onTap: () {
                      context.read<EditorBloc>().add(
                        ClipDeleted(trackId: trackId, clipId: clip.id),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildToolbarItem({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  Widget? badge,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (badge != null) Positioned(top: 5, right: 0, child: badge),
        ],
      ),
    ),
  );
}
