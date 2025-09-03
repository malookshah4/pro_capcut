// lib/presentation/widgets/editor_toolbars.dart
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';

enum EditorToolbar { main, audio, edit }

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
        onTap: onTap, // Pass the tap event directly up
        backgroundColor: const Color.fromARGB(255, 22, 22, 22),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(EvaIcons.edit), label: 'Edit'),
          BottomNavigationBarItem(icon: Icon(EvaIcons.music), label: 'Audio'),
          BottomNavigationBarItem(icon: Icon(Icons.text_fields), label: 'Text'),
          BottomNavigationBarItem(icon: Icon(Icons.waves), label: 'Stabilize'),
          BottomNavigationBarItem(icon: Icon(Icons.layers), label: 'Overlay'),
        ],
      ),
    );
  }
}

// The Edit Toolbar Widget
class EditToolbar extends StatelessWidget {
  const EditToolbar({super.key});

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
                  context.read<EditorBloc>().add(const ClipTapped(null)),
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
                      final editorBloc = context.read<EditorBloc>();
                      final currentState = editorBloc.state;
                      if (currentState is EditorLoaded &&
                          currentState.selectedClipIndex != null) {
                        editorBloc.add(
                          ClipSplitRequested(
                            clipIndex: currentState.selectedClipIndex!,
                            splitAt: currentState.videoPosition,
                          ),
                        );
                      }
                    },
                  ),
                  _buildToolbarItem(
                    icon: Icons.speed,
                    label: 'Speed',
                    onTap: () {},
                  ),
                  _buildToolbarItem(
                    icon: Icons.volume_up_outlined,
                    label: 'Volume',
                    onTap: () {},
                  ),
                  _buildToolbarItem(
                    icon: Icons.animation,
                    label: 'Animations',
                    onTap: () {},
                  ),
                  _buildToolbarItem(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onTap: () {},
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

// The Audio Toolbar Widget
class AudioToolbar extends StatelessWidget {
  final VoidCallback onBack;
  const AudioToolbar({super.key, required this.onBack});

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
              onPressed: onBack,
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
                    icon: Icons.auto_fix_high,
                    label: 'Enhance Voice',
                    onTap: () {
                      context.read<EditorBloc>().add(AiEnhanceVoiceStarted());
                      onBack();
                    },
                  ),
                  _buildToolbarItem(
                    icon: Icons.mic_off_outlined,
                    label: 'Reduce Noise',
                    onTap: () {
                      context.read<EditorBloc>().add(NoiseReductionApplied());
                      onBack();
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

// Helper widget for a consistent button style
Widget _buildToolbarItem({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
