# Project Context — Snappic Mobile Photobooth App

This project is an iOS application built with Swift and either SwiftUI or UIKit
(developer will choose per file). The app behaves like a mobile version of
photobooth machines found in malls (e.g., Snappic). It allows users to choose a
layout, capture multiple photos, apply effects, edit a photo strip, and export
or share the final output.

---

## Target Devices and Requirements
- Physical test device: iPhone XR, iOS 18.3.1
- Must support both front and back cameras
- Must be tested on real device (camera cannot be tested on simulator)

---

## Main Features
### 1. Layout Selection
Users select a layout for their photo strip:
- Different templates (2-photo, 3-photo, 4-photo, and 6-photo)
- Preview thumbnails shown

### 2. Camera Screen
- Live camera preview using AVCaptureSession or SwiftUI CameraView
- Front/back camera toggle
- Shutter button
- Ability to retake or proceed
- Optional filters:
  - Simple color filters (warm, cool, B&W, vintage)
  - Real-time preview is preferred 

### 3. Editing Screen
After capturing the photos for the selected layout, user can edit the photo strip:
- Change border/background color (color picker)
- Add stickers
- Remove stickers individually
- Optional small UI transitions (fade, slide, etc.)

### 4. Exporting & Sharing
- Save final photo strip to Gallery (Photos)
- Generate a QR code that contains either:
  - A shareable link
  - The encoded image or some identifier
- User can scan QR code on another phone to download/view the output
- Share sheet integration (iOS share panel)

---

## Architecture Preferences
- **MVVM** structure
- Code must be **modular, readable, and clean**
- Use **async/await** for camera, save, or heavy operations
- Minimal singletons; use dependency injection when possible
- Use Swift Package Manager for any dependencies

---

## UI Style & Requirements
- Clean, modern, photobooth-style UI (see sample screenshots)
- Rounded cards
- Soft gradients
- Photobooth vertical layout (tall preview)
- Smooth animation when switching between photos or layouts

---

## Technical Notes
- Add required privacy keys in Info.plist:
  - NSCameraUsageDescription
  - NSPhotoLibraryAddUsageDescription
- Camera must support:
  - Switching cameras
  - Capturing still images
  - Possibly mirroring front camera

---

## What I Want the AI Agent To Do
When assisting with code:
- Always use this context to maintain consistent architecture and UI
- Use the filenames and folder structure already in the project
- Do not rewrite entire files unless instructed
- Provide code with clear file paths
- Explain changes briefly
- Keep code maintainable and scalable

The agent must act as a senior iOS engineer familiar with SwiftUI/UIKit, AVFoundation, image editing, and QR generation workflows.

---

## Future Possible Add-ons (Not required now)
- AI Auto-Enhance filter
- Face tracking for positioning in layouts
- Photo templates marketplace
