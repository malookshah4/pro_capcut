// lib/presentation/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_capcut/bloc/projects_bloc.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/screens/editor_screen.dart';
import 'package:pro_capcut/presentation/widgets/project_card.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _createNewProject(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null && context.mounted) {
      // BEST PRACTICE: Show a loading indicator for a better user experience.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );

      final projectId = const Uuid().v4();
      String? thumbnailPath;

      try {
        final thumbnailBytes = await VideoCompress.getByteThumbnail(
          video.path,
          quality: 30,
        );

        if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          thumbnailPath = '${dir.path}/thumb_$projectId.jpg';
          final file = File(thumbnailPath);
          await file.writeAsBytes(thumbnailBytes, flush: true);
        }
      } catch (e) {
        print("!!! ERROR generating thumbnail: $e");
        // Optionally show a user-facing error message here
      }

      final info = await FFprobeKit.getMediaInformation(video.path);
      final durationMs =
          (double.tryParse(info.getMediaInformation()?.getDuration() ?? '0') ??
              0) *
          1000;
      final totalDuration = Duration(milliseconds: durationMs.round());

      final initialClip = VideoClip(
        sourcePath: video.path,
        sourceDurationInMicroseconds: totalDuration.inMicroseconds,
        startTimeInSourceInMicroseconds: 0,
        endTimeInSourceInMicroseconds: totalDuration.inMicroseconds,
        uniqueId: const Uuid().v4(),
      );

      final newProject = Project(
        id: projectId,
        lastModified: DateTime.now(),
        videoClips: [initialClip],
        audioClips: [],
        thumbnailPath: thumbnailPath,
      );

      // Save the project. The BLoC's listener will automatically pick up this change.
      final projectsBox = Hive.box<Project>('projects');
      await projectsBox.put(newProject.id, newProject);

      if (context.mounted) {
        Navigator.pop(context); // Dismiss the loading indicator
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(project: newProject),
          ),
        );

        if (context.mounted) {
          context.read<ProjectsBloc>().add(LoadProjects());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... Your existing header and "New Project" button UI ...
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
                    onPressed: () {},
                  ),
                ],
              ),
            ),
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
            _buildProjectsList(), // This now uses BlocBuilder
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // REFACTORED: This widget now uses BlocBuilder for clean, reactive state management.
  Widget _buildProjectsList() {
    return BlocBuilder<ProjectsBloc, ProjectsState>(
      builder: (context, state) {
        if (state is ProjectsLoading) {
          return const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is ProjectsLoaded) {
          final projects =
              state.projects; // Projects are pre-sorted by the BLoC

          if (projects.isEmpty) {
            return const SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'No projects yet. Create one!',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                return ProjectCard(project: project);
              },
            ),
          );
        }

        // Fallback for any other state (e.g., an error state if you add one)
        return const SizedBox(
          height: 140,
          child: Center(
            child: Text(
              'Something went wrong.',
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      },
    );
  }
}
