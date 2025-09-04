import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/data/services/thumbnail_service.dart';
import 'package:pro_capcut/domain/models/video_clip.dart';

class TimeMarkers extends StatelessWidget {
  final Duration totalDuration;
  final double pixelsPerSecond;
  final double horizontalPadding;

  const TimeMarkers({
    super.key,
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TimeMarkersPainter(
        videoDuration: totalDuration,
        pixelsPerSecond: pixelsPerSecond,
        padding: horizontalPadding,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class TimeMarkersPainter extends CustomPainter {
  final Duration videoDuration;
  final double pixelsPerSecond;
  final double padding;

  TimeMarkersPainter({
    required this.videoDuration,
    required this.pixelsPerSecond,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.0;

    final int totalSeconds = videoDuration.inSeconds;
    if (totalSeconds <= 0) return;

    int intervalSeconds = 1;
    if (pixelsPerSecond < 50) intervalSeconds = 5;
    if (pixelsPerSecond < 10) intervalSeconds = 10;

    for (int sec = 0; sec <= totalSeconds; sec++) {
      final dx = padding + sec * pixelsPerSecond;

      if (dx > size.width) break;

      if (sec % intervalSeconds == 0) {
        canvas.drawLine(Offset(dx, 0), Offset(dx, 8), paint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: _format(Duration(seconds: sec)),
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(dx - (textPainter.width / 2), 10));
      }
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  bool shouldRepaint(covariant TimeMarkersPainter old) =>
      old.videoDuration != videoDuration ||
      old.pixelsPerSecond != pixelsPerSecond ||
      old.padding != padding;
}

// FIX: This widget is now just the row of clips and the add button
class VideoTimeline extends StatelessWidget {
  final List<VideoClip> clips;
  final int? selectedIndex;
  final Function(int?) onClipTapped;
  final double pixelsPerSecond;

  const VideoTimeline({
    super.key,
    required this.clips,
    required this.selectedIndex,
    required this.onClipTapped,
    required this.pixelsPerSecond,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...List.generate(clips.length, (index) {
            final clip = clips[index];
            final bool isSelected = selectedIndex == index;
            final clipWidth =
                clip.duration.inMilliseconds / 1000 * pixelsPerSecond;

            return GestureDetector(
              onTap: () => onClipTapped(isSelected ? null : index),
              child: Container(
                width: clipWidth,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.grey[800]!,
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: ClipTimelineItem(
                    key: ValueKey(clip.uniqueId),
                    clip: clip,
                  ),
                ),
              ),
            );
          }),
          _AddClipButton(),
        ],
      ),
    );
  }
}

class _AddClipButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        print("addclip button click");
        final ImagePicker picker = ImagePicker();
        final XFile? video = await picker.pickVideo(
          source: ImageSource.gallery,
        );
        if (video != null && context.mounted) {
          context.read<EditorBloc>().add(ClipAdded(File(video.path)));
        }
      },
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}

class ClipTimelineItem extends StatefulWidget {
  final VideoClip clip;
  const ClipTimelineItem({super.key, required this.clip});

  @override
  State<ClipTimelineItem> createState() => _ClipTimelineItemState();
}

class _ClipTimelineItemState extends State<ClipTimelineItem> {
  late final Future<List<Uint8List?>> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = ThumbnailService.getThumbnails(widget.clip.playablePath);
  }

  @override
  void didUpdateWidget(covariant ClipTimelineItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clip.playablePath != oldWidget.clip.playablePath) {
      setState(() {
        _thumbnailFuture = ThumbnailService.getThumbnails(
          widget.clip.playablePath,
        );
      });
    }
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
                      height: 60,
                    )
                  : Container(color: Colors.grey[800]),
            );
          }).toList(),
        );
      },
    );
  }
}
