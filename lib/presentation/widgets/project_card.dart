// lib/presentation/widgets/project_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pro_capcut/bloc/projects_bloc.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/presentation/screens/editor_screen.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  const ProjectCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMM dd, yyyy');

    return GestureDetector(
      onTap: () async {
        // Mark onTap as async
        await Navigator.push(
          // Await the navigation
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(project: project),
          ),
        );
        // This is re-added in the home_screen.dart fix, but keeping it
        // here for robustness when tapping existing cards.
        if (context.mounted) {
          context.read<ProjectsBloc>().add(LoadProjects());
        }
      },
      onLongPress: () {
        _showDeleteConfirmation(context, project);
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child:
                    (project.thumbnailPath != null &&
                        project.thumbnailPath!.isNotEmpty)
                    ? Image.file(
                        File(project.thumbnailPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        // BUG FIX: Make the key unique using lastModified.
                        // This forces a reload of the image from disk when the project is updated.
                        key: ValueKey(
                          project.id + project.lastModified.toIso8601String(),
                        ),
                        errorBuilder: (context, error, stackTrace) {
                          print(
                            'Error loading thumbnail for ${project.id}: $error',
                          );
                          return _placeholder();
                        },
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatter.format(project.lastModified),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... Omitted placeholder and delete confirmation methods for brevity ...
  Widget _placeholder() {
    return Container(
      color: Colors.grey[850],
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: Colors.white24,
          size: 40,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: const Text('Are you sure you want to delete this project?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context.read<ProjectsBloc>().add(DeleteProject(project.id));
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
