# Sora Project Scratchpad

## Background and Motivation
The Sora app allows users to download media content for offline viewing. The app includes an active downloads view and episode cells that show progress updates for ongoing downloads. The app uses notification-based updates to reflect download progress across the UI.

Currently, there's an issue where the download progress percentage in the anime details view (specifically in EpisodeCell) doesn't update properly in real-time. It only updates when the user exits the anime details view and comes back.

## Key Challenges and Analysis
We previously fixed competing updater issues in both ActiveDownloadRow and EpisodeCell components:

1. Initial issue: A timer-based approach was competing with a notification-based approach, causing inconsistent UI updates
2. Fix: We removed timers and rely solely on NotificationCenter updates

However, despite these changes, the download progress in EpisodeCell within the MediaInfoView doesn't update in real-time. After analysis, I've identified the following potential issues:

1. **Notification Reception Issue**: The EpisodeCell is properly listening for "downloadStatusChanged" notifications and calls `updateDownloadStatus()` when received, but the notification may not be triggering UI updates properly within the MediaInfoView context.

2. **Data Flow Problem**: When the notification is received, the EpisodeCell calls `updateDownloadStatus()` which updates the `downloadProgress` state variable, but this update might not be triggering a UI refresh in the parent context.

3. **View Lifecycle Issue**: The EpisodeCell within MediaInfoView might not be correctly responding to state changes when nested in the parent view hierarchy.

## Implementation Plan
After analyzing the code, I've identified the following strategies to fix the issue:

### Solution 1: Force UI Updates with a Refresh Trigger
The main issue appears to be that while notifications are properly received and the local state is updated, the UI isn't refreshing properly in the context of MediaInfoView. We can add a trigger mechanism to force UI updates:

1. In EpisodeCell:
   - Add a `@State private var refreshTrigger = false` property
   - In the `updateDownloadStatus()` method, toggle this value: `self.refreshTrigger.toggle()`
   - Add a modifier to the main view: `.id(refreshTrigger)` - this will force the view to rebuild when the trigger changes

2. Alternative approach:
   - Use the `@ObservableObject` pattern to make download status changes more observable
   - Create a download manager class that conforms to `ObservableObject`
   - Move the download status and progress tracking to this class
   - Use `@Published` properties to trigger UI updates automatically

### Solution 2: Elevate State Management
Another approach would be to move the download progress state management up to MediaInfoView:

1. Create a shared observable object responsible for tracking download progress for all episodes
2. Pass this object down to each EpisodeCell
3. When notifications are received, update the centralized state
4. Since the state is shared, updates will propagate to all cells

### Solution 3: More Explicit State Dependencies
Make the UI elements more explicitly dependent on the state:

1. Ensure that HStack displaying the download progress directly depends on the `downloadProgress` state:
```swift
HStack(spacing: 4) {
    Text("\(Int(downloadProgress * 100))%")
        .font(.caption)
        .foregroundColor(.secondary)
    
    ProgressView(value: downloadProgress)
        .progressViewStyle(LinearProgressViewStyle())
        .frame(width: 40)
}
.id("progress_\(Int(downloadProgress * 100))")
```

2. Add a specific ID to force refreshes based on the actual progress value

### Recommended Approach
We should first try Solution 1 since it's the least invasive and doesn't require major architecture changes. If that doesn't work, we can move to Solution 2 which provides a more robust state management approach.

## Implementation Status
We have now implemented Solution 1 with the following changes:

1. Added a new state variable to track refresh triggers:
   ```swift
   @State private var downloadRefreshTrigger: Bool = false
   ```

2. Added an ID to the download progress UI component that's based on the actual progress percentage:
   ```swift
   .id("progress_\(Int(downloadProgress * 100))")
   ```

3. Added an ID to the entire view that combines the episode, refresh trigger, and progress percentage:
   ```swift
   .id("\(episode)_\(downloadRefreshTrigger)_\(Int(downloadProgress * 100))")
   ```

4. Updated the `updateDownloadStatus()` method to toggle the refresh trigger when the progress changes:
   ```swift
   // Toggle the refresh trigger to force a UI update
   downloadRefreshTrigger.toggle()
   ```

5. Added the same trigger toggle when the download status changes from downloading to not downloading:
   ```swift
   // Also toggle refresh trigger when status changes to not downloading
   if case .downloading = previousStatus {
       downloadRefreshTrigger.toggle()
   }
   ```

These changes should force the UI to rebuild whenever the download progress changes or when the download status changes, ensuring that the progress is always up-to-date in real-time.

The build has completed successfully with only unrelated warnings. The implementation is ready for testing.

## High-level Task Breakdown
- [x] Identify the cause of inconsistent progress updates in the active downloads view
- [x] Fix the ActiveDownloadRow component to use notification-based updates only
- [x] Fix the EpisodeCell component to use notification-based updates only
- [x] Add proper state tracking for download progress in EpisodeCell
- [x] Investigate why download progress updates work properly in the Downloads view but not in MediaInfoView
- [x] Implement a solution to ensure download progress updates in real-time in MediaInfoView
  - [x] Implement Solution 1: Add refresh trigger in EpisodeCell
  - [ ] If Solution 1 fails, implement Solution 2 or 3
- [ ] Test that progress updates work correctly in both the Downloads view and MediaInfoView

## Project Status Board
- [x] Fix ActiveDownloadRow progress updates (no longer uses timer, relies only on notifications)
- [x] Fix EpisodeCell progress updates
  - [x] Add separate `downloadProgress` state to track download progress 
  - [x] Update downloadProgress state when notifications are received
  - [x] Display download progress from state variable instead of directly from JSActiveDownload
- [x] Fix MediaInfoView download progress updates
  - [x] Investigate why notifications don't trigger UI updates in MediaInfoView
  - [x] Implement Solution 1: Add refresh trigger to force UI updates
  - [ ] Test progress updates with real downloads in MediaInfoView
- [ ] Verify progress updates in both UI components with real downloads

## Next Steps for User Testing
The implementation is now ready for testing. To verify that our solution works correctly:

1. Run the app on a device or simulator
2. Navigate to an anime details view that has episodes available for download
3. Start downloading an episode
4. Observe whether the progress percentage updates in real-time
5. Verify that the progress bar updates continuously as the download progresses
6. Ensure that the download status changes correctly when the download completes

If any issues are observed during testing, we can further refine our solution by:
1. Implementing additional diagnostic logging to trace notification reception and UI updates
2. Considering Solution 2 or 3 if Solution 1 doesn't fully resolve the issue
3. Adding more robust error handling to ensure progress updates don't fail silently

## Executor's Feedback or Assistance Requests
I've implemented Solution 1 to fix the download progress updates in the anime details view. The changes involve adding a refresh trigger mechanism that forces UI updates when download progress changes or when a download completes.

This approach should resolve the issue without requiring significant architectural changes. The implementation:

1. Forces a redraw of the progress UI itself when the progress value changes
2. Forces a redraw of the entire EpisodeCell when download status changes
3. Uses a combination of the episode ID, a refresh trigger, and the progress percentage as a unique ID to ensure proper updates

This solution should handle all update scenarios:
- When download progress changes incrementally
- When download status changes (from downloading to completed or vice versa)
- When navigating back to the anime details view (existing functionality)

The changes have been successfully built and are ready for testing.

## Lessons
- When using notification-based updates, make sure to maintain a local state variable for values that need to be displayed in the UI
- Remove competing update mechanisms (timers vs. notifications) to ensure consistent UI updates
- For download progress, using notifications is more efficient as it only updates when there's an actual change
- State management in nested SwiftUI views can be complex, especially when external events like notifications need to trigger UI updates
- When state updates aren't triggering UI refreshes, consider using the `.id()` modifier with a unique value that changes when the state changes to force a redraw

## Key Changes
- The `statusCheckTimer` variable has been removed from `EpisodeCell` as it's no longer needed.
- The `downloadProgress` state variable has been added to `EpisodeCell` to track download progress.
- The `downloadProgress` state variable is updated whenever a download status notification is received.
- The `downloadProgress` state variable is used to display download progress instead of directly from the `JSActiveDownload` object.
- Added a `downloadRefreshTrigger` state variable to force UI updates.
- Added ID modifiers to ensure the UI refreshes when download progress or status changes. 