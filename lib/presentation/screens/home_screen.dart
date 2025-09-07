// lib/presentation/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_capcut/presentation/screens/editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _createNewProject(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(videoFile: File(video.path)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111), // Dark background color
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Bar with Title and Search
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FreeCut',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      // TODO: Implement search functionality
                    },
                  ),
                ],
              ),
            ),

            // 2. New Project Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: GestureDetector(
                onTap: () => _createNewProject(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'New Project',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Projects List Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'My Projects',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // This is where your horizontal list of saved projects will go.
            // For now, it's a placeholder.
            _buildProjectsList(),

            const Spacer(), // Pushes content to the top
          ],
        ),
      ),
    );
  }

  // Placeholder widget for the horizontal project list
  Widget _buildProjectsList() {
    // In a real app, this would be a ListView.builder fed by a list of project models.
    return SizedBox(
      height: 140, // Define a height for the scrollable area
      child: Center(
        child: Text(
          'Saved projects will appear here',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }
}
