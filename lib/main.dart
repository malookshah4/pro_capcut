import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:pro_capcut/bloc/projects_bloc.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  // Register all your models
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(VideoClipAdapter());
  Hive.registerAdapter(AudioClipAdapter());
  // Open the box (like a table) where projects will be stored
  await Hive.openBox<Project>('projects');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Color.fromARGB(255, 40, 40, 40),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProjectsBloc()..add(LoadProjects()),
      child: MaterialApp(
        title: 'FreeCut',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        home: HomeScreen(),
      ),
    );
  }
}
