import 'package:flutter/material.dart';

class RatioOptionsSheet extends StatelessWidget {
  const RatioOptionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Format",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Options
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildOption(context, "Fit", null, Icons.crop_free),
                _buildOption(context, "9:16", 9 / 16, Icons.crop_portrait),
                _buildOption(context, "16:9", 16 / 9, Icons.crop_landscape),
                _buildOption(context, "1:1", 1.0, Icons.crop_square),
                _buildOption(
                  context,
                  "4:3",
                  4 / 3,
                  Icons.crop_7_5,
                ), // Close approximation icon
                _buildOption(context, "3:4", 3 / 4, Icons.crop_5_4),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    String label,
    double? ratio,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, ratio),
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
