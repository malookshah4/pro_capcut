import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_capcut/data/services/thumbnail_service.dart';
import 'package:pro_capcut/domain/models/video_clip.dart'; // --- ADDED: Import the new model ---

class TimeMarkers extends StatelessWidget {
  final Duration videoDuration;
  const TimeMarkers({super.key, required this.videoDuration});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TimeMarkersPainter(videoDuration: videoDuration),
      child: const SizedBox.expand(),
    );
  }
}

class TimeMarkersPainter extends CustomPainter {
  final Duration videoDuration;
  TimeMarkersPainter({required this.videoDuration});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.0;
    final int totalSeconds = videoDuration.inSeconds;
    if (totalSeconds <= 0) return;

    int markerCount = 5;
    final markers = List<int>.generate(
      markerCount,
      (i) => ((totalSeconds / (markerCount - 1)) * i).round(),
    );
    for (int i = 0; i < markers.length; i++) {
      final sec = markers[i];
      final dx = (i / (markers.length - 1)) * size.width;
      canvas.drawLine(Offset(dx, 0), Offset(dx, 8), paint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: _format(Duration(seconds: sec)),
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      double tx = dx - (textPainter.width / 2);
      if (i == 0) tx = dx;
      if (i == markers.length - 1) tx = dx - textPainter.width;
      textPainter.paint(canvas, Offset(tx, 10));
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  bool shouldRepaint(covariant TimeMarkersPainter old) =>
      old.videoDuration != videoDuration;
}

class VideoTimeline extends StatelessWidget {
  // --- MODIFIED: Now accepts a list of VideoClip objects ---
  final List<VideoClip> clips;
  final Duration videoDuration;
  final int? selectedIndex;
  final Function(int? index) onClipTapped;

  const VideoTimeline({
    super.key,
    required this.clips,
    required this.videoDuration,
    required this.selectedIndex,
    required this.onClipTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 20, child: TimeMarkers(videoDuration: videoDuration)),
        Container(
          height: 50,
          margin: const EdgeInsets.only(top: 8),
          child: Row(
            children: List.generate(clips.length, (index) {
              final clip = clips[index]; // --- Get the current clip ---
              final bool isSelected = selectedIndex == index;
              return Expanded(
                // --- Use flex to size clips proportionally by their duration ---
                flex: clip.duration.inMilliseconds,
                child: GestureDetector(
                  onTap: () => onClipTapped(isSelected ? null : index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: ClipTimelineItem(
                        // --- Use the uniqueId for the key for reliability ---
                        key: ValueKey(clip.uniqueId),
                        // --- Pass the playablePath to the thumbnail generator ---
                        videoPath: clip.playablePath,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class ClipTimelineItem extends StatefulWidget {
  final String videoPath;
  const ClipTimelineItem({super.key, required this.videoPath});

  @override
  State<ClipTimelineItem> createState() => _ClipTimelineItemState();
}

class _ClipTimelineItemState extends State<ClipTimelineItem> {
  late final Future<List<Uint8List?>> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = ThumbnailService.getThumbnails(widget.videoPath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List?>>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: Colors.grey[850]);
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            color: Colors.grey[900],
            child: const Icon(Icons.error, color: Colors.white24),
          );
        }

        final thumbnails = snapshot.data!;

        return Row(
          children: thumbnails.map((thumbData) {
            return Expanded(
              child: thumbData != null
                  ? Image.memory(
                      thumbData,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      height: 50,
                    )
                  : Container(color: Colors.grey[800]),
            );
          }).toList(),
        );
      },
    );
  }
}
