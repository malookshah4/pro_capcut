// lib/domain/models/timeline_clip.dart
import 'package:hive/hive.dart';

// This is an abstract "base class" for all clips.
// We don't register it with Hive directly, but its children will be.
abstract class TimelineClip {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int startTimeInTimelineInMicroseconds;

  @HiveField(2)
  final int durationInMicroseconds;

  TimelineClip({
    required this.id,
    required this.startTimeInTimelineInMicroseconds,
    required this.durationInMicroseconds,
  });

  Duration get startTime =>
      Duration(microseconds: startTimeInTimelineInMicroseconds);
  Duration get duration => Duration(microseconds: durationInMicroseconds);
  Duration get endTime => startTime + duration;
}
