import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pro_capcut/domain/models/project.dart';

part 'projects_event.dart';
part 'projects_state.dart';

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  ProjectsBloc() : super(ProjectsLoading()) {
    on<LoadProjects>(_onLoadProjects);
    on<DeleteProject>(_onDeleteProject);

    final projectsBox = Hive.box<Project>('projects');
    projectsBox.listenable().addListener(() {
      // It's good practice to check if the bloc is closed before adding events
      if (!isClosed) {
        add(LoadProjects()); // reload when Hive changes
      }
    });
  }

  Future<void> _onLoadProjects(
    LoadProjects event,
    Emitter<ProjectsState> emit,
  ) async {
    final projectsBox = Hive.box<Project>('projects');
    final projects = projectsBox.values.toList();
    projects.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    // ✨ FIX: Pass in the current DateTime to make the state unique.
    emit(ProjectsLoaded(projects, DateTime.now()));
  }

  Future<void> _onDeleteProject(
    DeleteProject event,
    Emitter<ProjectsState> emit,
  ) async {
    final box = Hive.box<Project>('projects');
    final projectToDelete = box.get(event.projectId);

    // This will trigger the Hive listener, which will then call _onLoadProjects
    await box.delete(event.projectId);

    if (projectToDelete?.thumbnailPath != null) {
      try {
        final thumbnailFile = File(projectToDelete!.thumbnailPath!);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      } catch (e) {
        print('Error deleting thumbnail file: $e');
      }
    }
    // No need to emit here, the listener handles it.
  }
}
