// lib/domain/models/audio_clip.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'audio_clip.g.dart';

@immutable
@HiveType(typeId: 2)
class AudioClip extends Equatable {
  @HiveField(0)
  final String filePath;

  @HiveField(1)
  final String uniqueId;

  @HiveField(2)
  final int durationInMicroseconds;

  @HiveField(3)
  final int startTimeInTimelineInMicroseconds;

  // --- THIS CONSTRUCTOR IS NOW CORRECTED ---
  const AudioClip({
    required this.filePath,
    required this.uniqueId,
    required this.durationInMicroseconds,
    required this.startTimeInTimelineInMicroseconds,
  });

  Duration get duration => Duration(microseconds: durationInMicroseconds);
  Duration get startTimeInTimeline =>
      Duration(microseconds: startTimeInTimelineInMicroseconds);

  @override
  List<Object?> get props => [
    filePath,
    uniqueId,
    durationInMicroseconds,
    startTimeInTimelineInMicroseconds,
  ];
}
