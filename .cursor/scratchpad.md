# Project Scratchpad

## Background and Motivation

The user has requested to add queued episodes to the list in the downloadview so users have the ability to cancel them. Currently, the download system has a queue mechanism where episodes are queued when concurrent download limits are reached, but queued downloads are not clearly visible in the downloadview's interface for user management.

**Current Implementation Status:**
- DownloadView has two tabs: "Active" and "Downloaded"  
- Active tab shows activeDownloads with cancel functionality for queued items
- Queue system exists in JSController with downloadQueue array
- Queued downloads show "Queued" status but limited visibility
- Cancel functionality exists for queued downloads via `cancelQueuedDownload()`

**User Requirements:**
- Add queued episodes to the downloadview list
- Provide cancel functionality for queued episodes
- Improve user visibility and control over download queue

**NEW BUG REPORT:**
- When canceling a download, the system incorrectly treats it as completed
- Canceled downloads still download subtitles 
- Already downloaded assets are not deleted after cancellation
- Need to differentiate between cancellation and completion states

## Key Challenges and Analysis

**VERIFICATION COMPLETED:**

Examining the download flow to understand current behavior:

1. **Download Initiation Flow:**
   - `startDownload()` creates `JSActiveDownload` with `queueStatus: .queued`
   - Download gets added to `downloadQueue` array (line 169 in JSController-Downloads.swift)
   - Download is NOT immediately added to `activeDownloads`

2. **Queue Processing Flow:**
   - `processDownloadQueue()` moves items from `downloadQueue` to `activeDownloads` when slots available
   - `startQueuedDownload()` creates new download object with `queueStatus: .downloading`
   - Only at this point does download get added to `activeDownloads` (line 260)

3. **UI Display Logic:**
   - DownloadView only shows `jsController.activeDownloads` (line 71 in DownloadView.swift)
   - UI does NOT display items from `downloadQueue`
   - `downloadQueue` is NOT @Published, so UI cannot observe it

4. **Current @Published Properties in JSController:**
   - `@Published var activeDownloads: [JSActiveDownload] = []` ✅ (visible in UI)
   - `var downloadQueue: [JSActiveDownload] = []` ❌ (NOT @Published, not visible in UI)

**CONFIRMED ISSUE:** 
Queued downloads waiting in `downloadQueue` (before they start downloading) are completely invisible to users in the DownloadView interface and cannot be cancelled via the UI. Users have no visibility into what episodes are waiting to be downloaded.

**Technical Gap:**
- Need to expose `downloadQueue` to UI (make it @Published)
- Need to display queued items in DownloadView 
- Need to provide cancel functionality for queued items (already exists in JSController)

## High-level Task Breakdown

*[To be filled by Planner]*

## Project Status Board

**EXECUTOR MODE ACTIVATED:**

- [x] **Task 1**: Make `downloadQueue` @Published in JSController to expose it to UI ✅
- [x] **Task 2**: Update DownloadView to display queued downloads alongside active downloads ✅
- [x] **Task 3**: Ensure cancel functionality works properly for queued items ✅
- [x] **Task 4**: Test the implementation to verify queued downloads are visible and cancellable ✅

**ORIGINAL TASK COMPLETED** - Queued episodes are now visible in downloadview with cancel functionality

**NEW REQUIREMENT ADDED:**
- [ ] **Task 5**: Add max concurrent downloads setting to SettingsView
- [ ] **Task 6**: Make the setting persist using @AppStorage
- [ ] **Task 7**: Update JSController to use the setting value instead of hardcoded 3
- [ ] **Task 8**: Test the concurrent download limit functionality

**BUG FIX REQUIRED:**
- [x] **Task 9**: Fix download cancellation behavior to differentiate from completion ✅
  - Prevent subtitle download when cancelled ✅
  - Delete already downloaded assets when cancelled ✅
  - Ensure cancelled downloads don't show as completed ✅

**Success Criteria:**
- ✅ Queued downloads appear in the "Active" tab of DownloadView
- ✅ Users can see how many downloads are queued
- ✅ Users can cancel queued downloads from the UI
- ✅ Existing active download functionality remains unchanged
- [ ] Users can configure max concurrent downloads in Settings
- [ ] Setting persists between app sessions
- [ ] Download queue respects the user-configured limit

## Current Status / Progress Tracking

**COMPLETED:** Original task - Queued download visibility implemented successfully
**COMPLETED:** New task - Adding max concurrent downloads setting
**COMPLETED:** Bug fix - Download cancellation behavior

**EXECUTOR MODE COMPLETED:**

✅ **Task 9: Fix download cancellation behavior** - IMPLEMENTED
- Added URLError.cancelled detection in `urlSession(_:task:didCompleteWithError:)`
- Created dedicated `handleDownloadCancellation()` method for proper cleanup
- Added `cancelledDownloadIDs` tracking to prevent race conditions
- Added early exit check in `didFinishDownloadingTo` to prevent completion processing for cancelled downloads
- Implemented `deletePartiallyDownloadedAsset()` to clean up any saved assets from cancelled downloads
- Prevented subtitle downloads for cancelled downloads through early return
- Ensured proper cleanup in `cleanupDownloadTask()` method

**READY FOR TESTING:**
- Test cancelling a download before completion
- Verify cancelled downloads don't appear as completed
- Verify no subtitle download occurs for cancelled downloads  
- Verify downloaded assets are properly deleted when cancelled

**BUG FIX IMPROVED:**
- Fixed race condition where subtitles were still downloaded for cancelled downloads
- Added immediate cancellation marking in UI (cancelActiveDownload method) 
- Added additional subtitle download prevention check
- Now properly prevents subtitle downloads by marking cancellation immediately when user clicks cancel

## Executor's Feedback or Assistance Requests

*[To be filled by Executor when assistance is needed]*

## Lessons

*[Document any solutions, fixes, or learnings during implementation]*

- **Fixed compilation error**: `processDownloadQueue` method was defined as `private` in JSController-Downloads.swift but was being called from JSController.swift. Changed method visibility from `private` to `func` (internal) to allow cross-file access within the same module.

- **Fixed UI status update issue**: When increasing max concurrent downloads, queued downloads weren't properly updating from "queued" to "downloading" status in the UI. Enhanced the following methods with explicit UI updates:
  - `processDownloadQueue()`: Added `objectWillChange.send()` and status notifications before starting downloads, with staggered timing for proper UI updates
  - `startQueuedDownload()`: Added comprehensive UI refresh including `objectWillChange.send()`, multiple notification types, and episode-specific status notifications
  - `updateMaxConcurrentDownloads()`: Added proper async UI updates with delays to ensure smooth status transitions
  
  The fix ensures UI elements properly reflect status changes when downloads transition from queued to downloading state.

- **Fixed download cancellation behavior**: Downloads that were cancelled by users were still being processed as completed downloads, including downloading subtitles and marking as completed. Implemented comprehensive cancellation handling:
  - Added `URLError.cancelled` detection in error handler to differentiate from other errors
  - Created `cancelledDownloadIDs` Set to track cancelled downloads and prevent race conditions
  - Added early exit check in `didFinishDownloadingTo` to prevent completion processing for cancelled downloads
  - Implemented `deletePartiallyDownloadedAsset()` to clean up any assets that may have been partially saved
  - Ensured subtitle downloads are prevented for cancelled downloads through early return mechanism
  - Added proper cleanup in `cleanupDownloadTask()` to remove cancelled download tracking
  
  The fix ensures cancelled downloads are properly cleaned up without being treated as completed downloads. 