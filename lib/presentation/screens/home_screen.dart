// lib/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_capcut/bloc/projects_bloc.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/screens/editor_screen.dart';
import 'package:pro_capcut/presentation/widgets/project_card.dart';
import 'package:pro_capcut/utils/thumbnail_utils.dart';
import 'package:uuid/uuid.dart';
// New imports
import 'package:pro_capcut/domain/models/editor_track.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProjectsBloc>().add(LoadProjects());
  }

  Future<void> _createNewProject(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null || !context.mounted) return;

    // Show the progress dialog
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

    // --- NEW: Error Handling Block ---
    try {
      final projectId = const Uuid().v4();

      // 1. Generate Thumbnail
      final String? thumbnailPath =
          await ThumbnailUtils.generateAndSaveThumbnail(video.path, projectId);

      // 2. Get Video Info
      final info = await FFprobeKit.getMediaInformation(video.path);
      final durationMs =
          (double.tryParse(info.getMediaInformation()?.getDuration() ?? '0') ??
              0) *
          1000;
      final totalDuration = Duration(milliseconds: durationMs.round());

      // 3. Build New Data Models
      final initialClip = VideoClip(
        id: const Uuid().v4(),
        sourcePath: video.path,
        sourceDurationInMicroseconds: totalDuration.inMicroseconds,
        startTimeInSourceInMicroseconds: 0,
        endTimeInSourceInMicroseconds: totalDuration.inMicroseconds,
        startTimeInTimelineInMicroseconds: 0,
        durationInMicroseconds: totalDuration.inMicroseconds,
      );

      final mainVideoTrack = EditorTrack(
        id: const Uuid().v4(),
        type: TrackType.video,
        clips: [initialClip], // This is now a List<dynamic>
      );

      final newProject = Project(
        id: projectId,
        lastModified: DateTime.now(),
        tracks: [mainVideoTrack],
        thumbnailPath: thumbnailPath,
      );

      // 4. Save to Hive (This is where it likely failed before)
      final projectsBox = Hive.box<Project>('projects');
      await projectsBox.put(newProject.id, newProject);

      // 5. Success: Close dialog and open editor
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
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
    } catch (e, stackTrace) {
      // 6. Failure: Close dialog and show error
      print("--- FAILED TO CREATE PROJECT ---");
      print(e.toString());
      print(stackTrace.toString());
      print("---------------------------------");

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to create project: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    // --- END: Error Handling Block ---
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _buildProjectsList(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsList() {
    final projectsBox = Hive.box<Project>('projects');
    return ValueListenableBuilder(
      valueListenable: projectsBox.listenable(),
      builder: (context, Box<Project> box, _) {
        final projects = box.values.toList();
        projects.sort((a, b) => b.lastModified.compareTo(a.lastModified));
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
      },
    );
  }
}
