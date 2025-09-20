// lib/presentation/widgets/editor_toolbars.dart
import 'dart:io';

import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
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
        selectedItemColor: Colors.grey,
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
  // NEW: Callbacks for each button press
  final VoidCallback onBack;
  final VoidCallback onSplit;
  final VoidCallback onSpeed;
  final VoidCallback onVolume;
  final VoidCallback onDelete;

  const EditToolbar({
    super.key,
    required this.onBack,
    required this.onSplit,
    required this.onSpeed,
    required this.onVolume,
    required this.onDelete,
  });

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
              // Use the onBack callback
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
                    icon: Icons.cut,
                    label: 'Split',
                    // Use the onSplit callback
                    onTap: onSplit,
                  ),
                  _buildToolbarItem(
                    icon: Icons.speed,
                    label: 'Speed',
                    // Use the onSpeed callback
                    onTap: onSpeed,
                  ),
                  _buildToolbarItem(
                    icon: Icons.volume_up_outlined,
                    label: 'Volume',
                    // Use the onVolume callback
                    onTap: onVolume,
                  ),
                  _buildToolbarItem(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    // Use the onDelete callback
                    onTap: onDelete,
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
                color: Colors.grey,
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
                    icon: Icons.queue_music_rounded,
                    label: "Extract",
                    onTap: () async {
                      final picker = ImagePicker();
                      final video = await picker.pickVideo(
                        source: ImageSource.gallery,
                      );
                      if (video != null && context.mounted) {
                        context.read<EditorBloc>().add(
                          AudioExtractedAndAdded(File(video.path)),
                        );
                      }
                    },
                    badge: Icon(
                      Icons.diamond_rounded,
                      size: 12,
                      color: Colors.blue,
                    ),
                  ),
                  _buildToolbarItem(
                    icon: Icons.auto_fix_high,
                    label: 'Enhance Audio',
                    onTap: () {},
                  ),
                  _buildToolbarItem(
                    icon: Icons.mic_off_outlined,
                    label: 'Reduce Noise',
                    badge: Text(
                      "AI",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      context.read<EditorBloc>().add(AiEnhanceVoiceStarted());
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
