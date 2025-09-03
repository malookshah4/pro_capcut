import 'dart:io';

import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_capcut/presentation/screens/editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // This function will handle picking a video
  void _createNewProject(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null && context.mounted) {
      // Navigate to the Editor Screen with the selected video file
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(videoFile: File(video.path)),
        ),
      );
    } else {
      print('No video selected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FreeCut',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // This will later be a list of user projects
            const Text(
              'No Projects Yet',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // Our accent color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () => _createNewProject(context),
              icon: const Icon(EvaIcons.plus),
              label: const Text('New Project'),
            ),
          ],
        ),
      ),
    );
  }
}
