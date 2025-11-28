# Transition Preview Fix for FreeCut Editor

## Problem
Transitions were being applied during **export only**, but were **NOT visible** during playback in the editor. Users could not see the transition effects (fade, slide, wipe, circle) while editing, unlike CapCut.

## Root Cause
The `PlaybackCoordinator` was already tracking:
- `activeController` - Current video playing
- `incomingController` - Next video (preloaded during transition)
- `transitionProgress` - Progress value (0.0 to 1.0)
- `currentTransition` - Transition type (fade, slideleft, etc.)

**BUT** the `editor_screen.dart` was only rendering the `activeController` using a simple `VideoPlayer` widget, ignoring the incoming controller and transition data.

## Solution

### 1. Created `TransitionRenderer` Widget
**File**: `lib/presentation/widgets/transition_renderer.dart`

This widget blends two video controllers based on transition type and progress:

#### Supported Transitions:
1. **Fade** - Cross-dissolve (opacity transition)
2. **Slide Left** - Push from right to left
3. **Slide Right** - Push from left to right
4. **Wipe** - Hard-edge wipe reveal
5. **Circle** - Expanding circle reveal

#### Key Features:
- Uses `Stack` to overlay both controllers
- Applies Flutter animations (Opacity, FractionalTranslation, ClipPath)
- Custom clippers for wipe and circle effects
- Automatically shows single video when not in transition

### 2. Updated `editor_screen.dart`
**File**: `lib/presentation/screens/editor_screen.dart`

Replaced the simple `VideoPlayer` with nested `ValueListenableBuilder`s that listen to:
- `_coordinator.incomingController`
- `_coordinator.transitionProgress`
- `_coordinator.currentTransition`

And render using `TransitionRenderer`.

## How It Works

### Timeline:
```
Clip A [--------]
               [====TRANSITION====]
                              Clip B [--------]
```

### During Playback:
1. **Before Transition**: Only `activeController` (Clip A) is shown
2. **1.5s Before Transition**: `PlaybackCoordinator` preloads Clip B into `incomingController`
3. **During Transition**:
   - `TransitionRenderer` receives both controllers
   - Progress animates from 0.0 → 1.0
   - Appropriate blend effect is applied
4. **After Transition**: `incomingController` becomes the new `activeController`

### Visual Example (Fade):
```dart
Stack(
  children: [
    Opacity(opacity: 1.0 - progress, child: VideoA),  // Fading out
    Opacity(opacity: progress, child: VideoB),         // Fading in
  ]
)
```

## Testing Checklist

1. ✅ Add 2+ video clips to timeline
2. ✅ Tap the transition button (between clips)
3. ✅ Select a transition type (Fade, Slide, etc.)
4. ✅ Adjust duration slider (0.1s - 2.0s)
5. ✅ Press play and watch the transition preview
6. ✅ Verify all 6 transition types work
7. ✅ Export and verify transitions work in final video

## Files Modified
- `lib/presentation/widgets/transition_renderer.dart` ← **NEW**
- `lib/presentation/screens/editor_screen.dart` ← Updated canvas builder

## Files Already Supporting Transitions
- `lib/utils/PlaybackCoordinator.dart` ← Transition logic exists
- `lib/utils/ffmpeg_command_builder.dart` ← Export transitions exist
- `lib/presentation/widgets/timeline_track_widget.dart` ← Transition UI exists
- `lib/bloc/editor_bloc.dart` ← Event handling exists

## Result
Transitions now **preview in real-time** during editor playback, matching the CapCut experience! 🎉
