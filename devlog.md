# RedReader Development Log

This document tracks the development history, bug fixes, and technical decisions made during the development of RedReader.

## April 2026

### Session 1: Critical Bug Fixes

#### 1. Storage Permissions (Android)
**Issue**: App crashed on Android due to missing or improperly requested storage permissions.

**Fix**: 
- Implemented `PermissionService` with SDK-aware permission requests
- Added `device_info_plus` for runtime SDK detection
- Different permission strategies for Android < 10, 10-12, and 13+
- Added rationale dialogs and permanently denied handling

**Files Changed**:
- `lib/services/permission_service.dart` (complete rewrite)
- `pubspec.yaml` (added device_info_plus)

---

#### 2. PDF Scanning (Android)
**Issue**: PDF files not being discovered on Android devices.

**Fix**:
- Created `MediaStoreService` for Android platform channel communication
- Implemented Kotlin `MainActivity.kt` with MediaStore query method
- Rewrote `FileScannerService` to use MediaStore on Android with directory fallback
- Added WhatsApp directory support

**Files Changed**:
- `lib/services/media_store_service.dart` (new file)
- `lib/services/file_scanner_service.dart` (rewrite)
- `android/app/src/main/kotlin/com/example/pdfviewer/MainActivity.kt` (updated)

---

#### 3. Thumbnail Aspect Ratio
**Issue**: PDF thumbnails were square instead of A4 portrait ratio.

**Fix**:
- Changed thumbnail generation to use 0.707 aspect ratio (A4 portrait)
- Aspect ratio calculation: `pageHeight / pageWidth` ≈ 1.414, so container uses 1/1.414 = 0.707

**Files Changed**:
- `lib/services/thumbnail_service.dart`
- `lib/widgets/pdf_card.dart`
- `lib/widgets/pdf_list_item.dart`
- `lib/widgets/bookmark_card.dart`

---

#### 4. Thumbnail Color Distortion
**Issue**: PDF thumbnails showed blue content as yellow (BGRA vs RGBA issue).

**Fix**:
- Added `_convertBGRAtoRGBA()` method in `ThumbnailService`
- Manually swaps B and R channels during pixel conversion

**Code**:
```dart
Uint8List _convertBGRAtoRGBA(Uint8List bgraBytes, int width, int height) {
  final rgbaBytes = Uint8List(bgraBytes.length);
  final pixelCount = width * height;
  for (int i = 0; i < pixelCount; i++) {
    final offset = i * 4;
    rgbaBytes[offset] = bgraBytes[offset + 2];     // R <- B
    rgbaBytes[offset + 1] = bgraBytes[offset + 1]; // G <- G
    rgbaBytes[offset + 2] = bgraBytes[offset];     // B <- R
    rgbaBytes[offset + 3] = bgraBytes[offset + 3]; // A <- A
  }
  return rgbaBytes;
}
```

**Files Changed**:
- `lib/services/thumbnail_service.dart`

---

#### 5. UI Text Cropping (Home Tab)
**Issue**: "Continue Reading" section text was cropped.

**Fix**:
- Increased container height from 280 to 320

**Files Changed**:
- `lib/screens/home/home_screen.dart`

---

#### 6. Reading History - Last Read Page
**Issue**: History tab showed incorrect page numbers.

**Fix**:
- Fixed `HistoryProvider` to properly load page numbers from reading history
- Corrected data mapping between history and document records

**Files Changed**:
- `lib/providers/history_provider.dart`

---

#### 7. Bookmarks Tab - Bookmarked Page Display
**Issue**: Bookmarks tab didn't show the correct bookmarked page for each PDF.

**Fix**:
- Updated `BookmarkProvider` to correctly display bookmarked page information
- Fixed data association between bookmarks and documents

**Files Changed**:
- `lib/providers/bookmark_provider.dart`

---

### Session 2: Bookmark Navigation Fix

#### Issue
Tapping a bookmark from the Bookmarks tab opened the PDF at page 1 instead of the bookmarked page.

#### Root Cause
The `jumpToPage()` call was happening too early in `addPostFrameCallback` before the PDF document was fully rendered, causing the jump to fail silently.

#### Solution
1. Added tracking flags to prevent premature jumping:
   - `_initialPageJumped` - boolean flag
   - `_pendingTargetPage` - stores target page until ready

2. Created `_schedulePageJump()` method:
   - Uses `addPostFrameCallback` + 500ms delay
   - Calls `_pdfController.goToPage()` after delay
   - Syncs with `ReaderProvider` for state consistency

3. Added retry logic in `_onPageChanged()`:
   - Detects if jump was missed
   - Retries automatically if still on page 1 but should be elsewhere

#### Files Changed
- `lib/screens/viewer/pdf_viewer_screen.dart`

---

### Session 3: UI Polish - Thumbnails & Text

#### 1. File Name Text - One Line with Ellipsis
**Issue**: PDF file names wrapped to 2 lines causing UI inconsistencies.

**Fix**:
- Changed `maxLines: 2` to `maxLines: 1`
- Added `softWrap: false`
- Added `overflow: TextOverflow.ellipsis`

**Files Changed**:
- `lib/widgets/pdf_card.dart` (file name text)
- `lib/widgets/pdf_list_item.dart` (file name text)
- `lib/widgets/bookmark_card.dart` (already correct)

---

#### 2. Thumbnail Cropping
**Issue**: Thumbnails were being clipped, cutting off page content.

**Fix**:
- Removed `ClipRRect` widgets that were clipping image content
- Added `alignment: Alignment.center` to all `Image.file` widgets
- All thumbnails use `BoxFit.contain` (no cropping)
- Container uses `AspectRatio(aspectRatio: 0.707)` for proper PDF proportions

**Files Changed**:
- `lib/widgets/pdf_card.dart` - removed ClipRRect, added Alignment.center
- `lib/widgets/pdf_list_item.dart` - added Alignment.center
- `lib/widgets/bookmark_card.dart` - removed ClipRRect, added Alignment.center

---

### Session 4: PDF Viewer Layout & Page Number Updates

#### 1. PDF Content Behind Top Bar
**Issue**: PDF page 1 started behind the top navigation bar.

**Fix**:
- Changed layout from `Stack` to `Column`
- Top bar now first child (not overlaying PDF)
- PDF viewer wrapped in `Expanded` fills space between bars
- Bottom bar is last child

**Before**:
```dart
Stack(
  children: [
    PdfViewer(...),  // Full screen, behind bars
    Positioned(top: 0, child: TopBar),
    Positioned(bottom: 0, child: BottomBar),
  ],
)
```

**After**:
```dart
Column(
  children: [
    TopBar,
    Expanded(child: PdfViewer(...)),  // Between bars only
    BottomBar,
  ],
)
```

**Files Changed**:
- `lib/screens/viewer/pdf_viewer_screen.dart` (build method)

---

#### 2. Page Number at Half-Threshold
**Issue**: Page number in bottom bar didn't update correctly during scroll.

**Fix**:
- Added `_displayedPage` state variable
- Created `_updatePageAtHalfThreshold()` method
- Updated `_onPageChanged()` to use new method
- Page updates propagate through `Future.microtask` to avoid build-phase setState issues

**Note**: The `pdfrx` package's `onPageChanged` callback handles threshold detection internally. The wrapper ensures page state stays synchronized.

**Files Changed**:
- `lib/screens/viewer/pdf_viewer_screen.dart`

---

## Technical Decisions

### PDF Package Choice: pdfrx
- Chosen over `pdfx` due to better Flutter 3.x compatibility
- Native performance with good page navigation APIs
- Supports zoom, scroll, and page callbacks

### State Management: Provider
- Simple and effective for this app scale
- Easy to test and debug
- No boilerplate compared to BLoC/Riverpod

### Database: SQLite via sqflite
- Reliable local storage
- Good for structured data (bookmarks, history, notes)
- Cross-platform support

### Thumbnail Strategy
- Generate on-demand and cache to file system
- 300px width for good quality/size balance
- PNG format for lossless quality

---

### Session 5: Immersive PDF Viewer Layout

#### Issue
PDF viewer was confined to a framed area between top and bottom bars, preventing full-screen immersive reading experience.

#### Solution
Changed layout from `Column` to `Stack` for full-screen PDF viewing:

**Before (Column layout)**:
```dart
Column(
  children: [
    TopBar,           // Top bar
    Expanded(
      child: PdfViewer(...),  // PDF confined between bars
    ),
    BottomBar,        // Bottom bar
  ],
)
```

**After (Stack layout)**:
```dart
Stack(
  children: [
    Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.only(top: 80), // Space for top bar
        child: PdfViewer(...),  // Full screen, can scroll behind bars
      ),
    ),
    Positioned(top: 0, child: TopBar),      // Overlays PDF
    Positioned(bottom: 24, child: BottomBar), // Overlays PDF
  ],
)
```

**Key Changes**:
- PDF now fills entire screen with `Positioned.fill`
- Top padding (80px) ensures page 1 starts below top bar
- Top bar and bottom bar are `Positioned` overlays floating on top
- PDF can scroll behind/under the UI bars for immersive experience
- UI bars fade in/out with animation controller

**Files Changed**:
- `lib/screens/viewer/pdf_viewer_screen.dart` (build method layout)

---

## Known Issues / TODO

- Search functionality not yet implemented
- Text highlighting not yet implemented
- Landscape PDFs may appear smaller in thumbnail containers (acceptable)
- iOS support not tested (Android/Linux only)

---

## Build Information

**Last Successful Build**: April 20, 2026
**Flutter Version**: 3.24.x
**Dart Version**: 3.5.x

**APK Sizes**:
- arm64-v8a: 28.1 MB
- armeabi-v7a: 23.9 MB
- x86_64: 29.7 MB
