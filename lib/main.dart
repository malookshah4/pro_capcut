// lib/main.dart
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:pro_capcut/bloc/projects_bloc.dart';
import 'package:pro_capcut/presentation/screens/home_screen.dart';

// --- Import ALL your models ---
import 'package:pro_capcut/domain/models/project.dart';
import 'package:pro_capcut/domain/models/editor_track.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';
import 'package:pro_capcut/domain/models/audio_clip.dart';
import 'package:pro_capcut/domain/models/text_clip.dart';
import 'package:pro_capcut/domain/models/text_style_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = await AudioSession.instance;
  await session.configure(
    const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.movie,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ),
  );

  // --- Hive Setup with Unique TypeIds ---
  await Hive.initFlutter();

  // Register adapters with UNIQUE typeIds
  Hive.registerAdapter(ProjectAdapter()); // typeId: 0
  Hive.registerAdapter(VideoClipAdapter()); // typeId: 1
  Hive.registerAdapter(AudioClipAdapter()); // typeId: 2
  Hive.registerAdapter(TextClipAdapter()); // typeId: 3
  Hive.registerAdapter(EditorTrackAdapter()); // typeId: 4
  Hive.registerAdapter(TextStyleModelAdapter()); // typeId: 6 (Cshanged from 3)
  Hive.registerAdapter(TrackTypeAdapter());

  await Hive.openBox<Project>('projects');
  // --- End of Hive setup ---

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
      create: (context) => ProjectsBloc(),
      child: MaterialApp(
        title: 'FreeCut',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
