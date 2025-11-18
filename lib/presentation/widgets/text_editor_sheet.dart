import 'package:flutter/material.dart';
import 'package:pro_capcut/domain/models/text_style_model.dart';

class TextEditorResult {
  final String text;
  final TextStyleModel style;

  TextEditorResult(this.text, this.style);
}

class TextEditorSheet extends StatefulWidget {
  final String? initialText;
  final TextStyleModel? initialStyle;

  const TextEditorSheet({super.key, this.initialText, this.initialStyle});

  @override
  State<TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<TextEditorSheet>
    with SingleTickerProviderStateMixin {
  late TextEditingController _textController;
  late TabController _tabController;
  late TextStyleModel _currentStyle;

  // Mock Data for Fonts (In a real app, you'd load Google Fonts)
  final List<String> _fontNames = [
    'System',
    'Modern',
    'Story',
    'Rubik',
    'Classic',
    'Italic',
    'Bold',
    'Retro',
  ];

  final List<int> _colors = [
    0xFFFFFFFF,
    0xFF000000,
    0xFFFF0000,
    0xFF00FF00,
    0xFF0000FF,
    0xFFFFFF00,
    0xFFFF00FF,
    0xFF00FFFF,
    0xFFFFA500,
    0xFF800080,
    0xFFE91E63,
    0xFF9C27B0,
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? "");
    _tabController = TabController(length: 2, vsync: this);
    _currentStyle = widget.initialStyle ?? TextStyleModel();
  }

  @override
  void dispose() {
    _textController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSave() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, TextEditorResult(text, _currentStyle));
  }

  @override
  Widget build(BuildContext context) {
    // CapCut style: Dark grey background with rounded top corners
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // --- 1. Top Actions Bar (Cancel / Check) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.tealAccent),
                  onPressed: _onSave,
                ),
              ],
            ),
          ),

          // --- 2. Text Input Area ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _textController,
                autofocus: true,
                style: _currentStyle.toFlutterTextStyle().copyWith(
                  fontSize: 18,
                ),
                decoration: const InputDecoration(
                  hintText: "Enter text...",
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
                maxLines: 1,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- 3. Tab Bar ---
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: "Fonts"),
              Tab(text: "Styles"),
            ],
          ),

          // --- 4. Tab Views ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFontsTab(), _buildStylesTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 2.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _fontNames.length,
      itemBuilder: (context, index) {
        final fontName = _fontNames[index];
        final isSelected =
            _currentStyle.fontName == fontName ||
            (fontName == 'System' && _currentStyle.fontName == 'System');

        return GestureDetector(
          onTap: () {
            setState(() {
              // In a real app, you would update the font family here
              // For now, we just store the name to simulate selection
              _currentStyle = TextStyleModel(
                fontName: fontName,
                fontSize: _currentStyle.fontSize,
                primaryColor: _currentStyle.primaryColor,
              );
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: Colors.tealAccent, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              fontName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStylesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Text Color",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _colors.length,
            itemBuilder: (context, index) {
              final color = _colors[index];
              final isSelected = _currentStyle.primaryColor == color;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentStyle = TextStyleModel(
                      fontName: _currentStyle.fontName,
                      fontSize: _currentStyle.fontSize,
                      primaryColor: color,
                    );
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : Border.all(color: Colors.white24, width: 1),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
