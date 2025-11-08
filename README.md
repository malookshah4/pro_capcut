✂️ FreeCut - Flutter Video Editor
FreeCut is a high-performance, project-based mobile video editor built with Flutter. It is designed to mirror the intuitive UI, core features, and user experience of the popular Capcut video editor.

The app is built on a robust, scalable architecture using BLoC for state management, FFmpeg for video processing, and Hive for local database persistence.

📸 Screenshots

![WhatsApp Image 2025-11-08 at 9 12 32 AM (3)](https://github.com/user-attachments/assets/1fb4b1ee-eac9-49bd-b79e-3a67ec8cf732)
![WhatsApp Image 2025-11-08 at 9 12 32 AM (2)](https://github.com/user-attachments/assets/2b85a6ad-4511-4327-ad54-ee5952f10b70)
![WhatsApp Image 2025-11-08 at 9 12 32 AM (1)](https://github.com/user-attachments/assets/16512e9e-f87b-4cff-b532-c8c806199102)
![WhatsApp Image 2025-11-08 at 9 12 32 AM](https://github.com/user-attachments/assets/ac95a37e-511f-4c91-a562-17b43ff04df3)

Home Screen (Project Hub)	Editor (Multi-Track Timeline)	Export Options	Exporting Progress

Export to Sheets

✨ Core Features
Project Management
Project-Based Workflow: Create, save, and re-open video projects.

Elegant Home Screen: A professional, horizontally-scrolling project hub that displays all your saved projects.

Project Thumbnails: Each project is represented by a visual thumbnail generated from the first video clip.

Auto-Saving: All progress is automatically saved to your device when you exit the editor.

Project Deletion: Safely delete old projects with a confirmation dialog to prevent accidental data loss.

Editing Timeline
Non-Destructive Editing: Your original video files are never modified. All edits are stored as instructions, ensuring a fast UI and zero loss of quality.

Multi-Track Timeline: A dynamic, scrollable timeline that supports multiple video and audio tracks.

Intuitive Clip Editing:

Trim: Precisely trim the start and end of clips using intuitive, draggable handles.

Split: Easily split video clips at any point on the timeline.

Audio Editing
Extract Audio: Pull the audio from any video clip onto its own separate track for independent editing.

Multi-Track Audio Mixing: The export engine correctly mixes the base video's audio with all additional, layered audio tracks.

Exporting
Custom Export Settings: Choose your desired resolution, frame rate, and code rate before exporting.

Dedicated Export Screen: A full-screen, professional export progress screen shows a video preview and a clear percentage indicator.

Powerful FFmpeg Engine: All video and audio processing is handled by FFmpeg, ensuring high-quality and reliable output.

🛠️ Architecture & Tech Stack
This project uses a modern, scalable architecture to ensure a clean separation of concerns and high performance.

Framework: Flutter

State Management: BLoC (Business Logic Component)

EditorBloc: Manages all real-time editing logic.

ProjectsBloc: Manages loading, creating, and deleting projects on the home screen.

Video/Audio Processing: ffmpeg_kit_flutter_new

Handles all heavy-lifting for trimming, splitting, audio extraction, and final video rendering.

Database: Hive

A lightweight, high-performance NoSQL database used to persist all project data (clip info, timelines, etc.) on the device.

Thumbnail Generation: video_compress

Used to generate thumbnails for the project home screen.

🚀 Getting Started
To run this project locally, follow these steps:

Clone the repository:

Bash

git clone https://github.com/YourUsername/FreeCut.git
Navigate to the project directory:

Bash

cd FreeCut
Install dependencies:

Bash

flutter pub get
Run the app:

Bash

flutter run
🗺️ Future Roadmap
FreeCut is in a stable, feature-rich state and is well-positioned for future development. Upcoming goals include:

Visual Effects: A library of filters and color-grading tools.

Transitions: Add a variety of transitions to apply between video clips.

Text & Overlays: Implement features for adding text, titles, and stickers.

⚖️ License
This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0).

This means you are free to:

Share — copy and redistribute the material in any medium or format.

Adapt — remix, transform, and build upon the material.

Under the following terms:

Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made.

NonCommercial — You may not use the material for commercial purposes.

ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.

This license explicitly prohibits any commercial use or public publishing of this project as a commercial product.

For the full license text, see CC BY-NC-SA 4.0 License.
