part of 'projects_bloc.dart';

abstract class ProjectsState extends Equatable {
  const ProjectsState();

  @override
  List<Object> get props => [];
}

class ProjectsLoading extends ProjectsState {}

class ProjectsLoaded extends ProjectsState {
  final List<Project> projects;

  // ✨ FIX 1: Add a timestamp to guarantee uniqueness for every state emission.
  final DateTime timestamp;

  const ProjectsLoaded(this.projects, this.timestamp);

  @override
  // ✨ FIX 2: Include the timestamp in the props for Equatable.
  List<Object> get props => [projects, timestamp];
}
