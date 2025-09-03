import 'package:flutter/material.dart';

class TimelineTrack extends StatelessWidget {
  final int trackIndex;
  final bool isSelected;
  final VoidCallback onTap;
  final List<Color> mockColors; // Using colors to generate mock thumbnails

  const TimelineTrack({
    super.key,
    required this.trackIndex,
    required this.isSelected,
    required this.onTap,
    required this.mockColors,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate padding to center the timeline start
    final screenWidth = MediaQuery.of(context).size.width;
    // We subtract half the width of a thumbnail (25) so the first item's left edge aligns with the center.
    final horizontalPadding = screenWidth / 2 - 25;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 4),
        // Apply the border decoration here, to the track itself
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: Colors.white, width: 2.5)
              : null,
          borderRadius: BorderRadius.circular(8.0),
        ),
        // ClipRRect ensures the scrolling content respects the border radius
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.0), // Slightly smaller radius
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            scrollDirection: Axis.horizontal,
            itemCount: mockColors.length,
            itemBuilder: (context, index) {
              // This is a mock thumbnail
              return Container(
                width: 50,
                height: 60,
                color: mockColors[index],
                margin: const EdgeInsets.symmetric(horizontal: 1.0),
                child: Center(
                  child: Text(
                    "$index",
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              );
              // In your real code, you would use your _thumbnails data like this:
              // final thumbData = _thumbnails[index];
              // return Image.memory(thumbData, ...);
            },
          ),
        ),
      ),
    );
  }
}
