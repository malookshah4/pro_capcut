// lib/bloc/projects_bloc/projects_event.dart
part of 'projects_bloc.dart';

abstract class ProjectsEvent extends Equatable {
  const ProjectsEvent();
  @override
  List<Object> get props => [];
}

class LoadProjects extends ProjectsEvent {}

class DeleteProject extends ProjectsEvent {
  final String projectId;
  const DeleteProject(this.projectId);
}
