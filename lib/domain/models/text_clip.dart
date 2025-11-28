// lib/domain/models/text_clip.dart
import 'package:hive/hive.dart';
import 'package:pro_capcut/domain/models/text_style_model.dart';
import 'package:pro_capcut/domain/models/timeline_clip.dart'; // Import new base class

part 'text_clip.g.dart';

@HiveType(typeId: 3) // Keep existing typeId
class TextClip extends TimelineClip {
  @HiveField(3) // Start fields after base class
  String text;

  @HiveField(4)
  TextStyleModel style;

  @HiveField(5)
  double offsetX;

  @HiveField(6)
  double offsetY;

  @HiveField(7)
  double scale;

  @HiveField(8)
  double rotation;

  TextClip({
    required super.id,
    required super.startTimeInTimelineInMicroseconds,
    required super.durationInMicroseconds,
    required this.text,
    required this.style,
    this.offsetX = 0.5,
    this.offsetY = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  TextClip copyWith({
    String? id,
    int? startTimeInTimelineInMicroseconds,
    int? durationInMicroseconds,
    String? text,
    TextStyleModel? style,
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotation,
  }) {
    return TextClip(
      id: id ?? this.id,
      startTimeInTimelineInMicroseconds:
          startTimeInTimelineInMicroseconds ??
          this.startTimeInTimelineInMicroseconds,
      durationInMicroseconds:
          durationInMicroseconds ?? this.durationInMicroseconds,
      text: text ?? this.text,
      style: style ?? this.style,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'text',
      'text': text,
      'style': style.toJson(), // Ensure TextStyleModel also has toJson
      'startTimeInTimeline': startTimeInTimelineInMicroseconds,
      'duration': durationInMicroseconds,

      // SAVE THESE FIELDS
      'offsetX': offsetX,
      'offsetY': offsetY,
      'scale': scale,
      'rotation': rotation,
    };
  }

  factory TextClip.fromJson(Map<String, dynamic> json) {
    return TextClip(
      id: json['id'],
      text: json['text'],
      style: TextStyleModel.fromJson(json['style']),
      startTimeInTimelineInMicroseconds: json['startTimeInTimeline'],
      durationInMicroseconds: json['duration'],

      // LOAD THESE FIELDS
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.5,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.5,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
