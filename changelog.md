# Changelog

## News Junkie tvOS R&D Summary

This document captures the major research, engineering, and UX work completed during the current development cycle for the Apple TV build of News Junkie Secret Shows.

## Core Platform Direction

- Established the Apple TV app as a native SwiftUI/tvOS client.
- Confirmed that an in-app splash experience can use an `mp4` with audio on tvOS, while noting that Apple does not allow a custom video before the actual launch screen.
- Kept the implementation lightweight and local-first where possible so the same design can be re-used on other platforms later.

## App Structure

- Built the app around a single `AppModel` state container that drives the entire screen flow.
- Standardized screen routing across:
  - splash
  - loading
  - login
  - access denied
  - library
  - detail
  - error
- Added persisted session and navigation restoration using `UserDefaults`.

## Backend Integration

- Implemented login against the News Junkie backend using the `user/login` action.
- Implemented user entitlement loading against `user/score`.
- Implemented Secret Shows catalog loading against `secretshows`.
- Added request headers and request-body formatting needed by the backend contract.
- Added robust decoding for legacy or inconsistent API payloads, including:
  - flexible string decoding
  - flexible integer decoding
  - flexible boolean decoding
  - tolerant handling of optional or malformed values
- Improved login failure handling by surfacing backend `non_field_errors`.

## Subscription and Access Control

- Enforced gating so the tvOS app only unlocks library access when the account has:
  - subscriber access
  - video entitlement
  - Secret Shows enabled
- Added an access denied screen that points the user to the News Junkie website when the required subscription is missing.

## Splash Experience

- Replaced the placeholder text splash with an in-app video splash.
- Added support for `images/NJ-TV-splash.mp4`.
- Preserved the six-hour splash replay rule using local foreground timestamp storage.
- Added tap-to-skip support for the splash.
- Removed the on-screen “Click to skip” hint after validating the interaction pattern.
- Updated splash replay behavior so the splash can appear again when reopening from the Home screen after the cooldown expires, not only on a cold launch.
- Added a hidden test gesture on the library screen so four quick `up` presses while `Log Out` is focused reset the splash cooldown for the next app open.

## Login Screen

- Added branded login artwork using `img_secret-player.png`.
- Reworked the login layout so the hero image sits above the `News Junkie Secret Shows` headline.
- Removed the old border treatment around the email and password inputs.
- Tuned focus and text colors so typed input remains readable:
  - black when focused
  - white when unfocused

## Library Screen

- Added a personalized greeting using `user_first_name`.
- Updated the library subtitle to `Browse the Secret Shows video library...`.
- Added a large hero header using:
  - `user_bg_image` as the top banner
  - `user_avatar_image` in a circular avatar overlap
- Increased avatar scale and adjusted banner height/spacing to better match the iOS visual feel.
- Added a logo-based placeholder poster using `img_secret-shows.png`.
- Removed the redundant `VIDEO` badge from each card.
- Reformatted show dates to `MM-DD-YYYY`.
- Moved date placement to the bottom-right of the card.
- Improved focused-card readability while keeping selected-card text white.
- Reworked selected-card visuals so focused titles and dates stay white.
- Brightened the selected card background and tightened the card inset so the focus state feels more intentional.
- Tuned the custom selected-card border to stay subtle and aligned with the outer card edge.
- Fixed selected-card text so focused titles and dates remain white.
- Set the focused card background boost to `0.30`.
- Changed card thumbnails to a fixed `381:200` ratio.
- Updated card posters to use a contained presentation with rounded corners instead of cropping.

## Detail Screen

- Built a dedicated show detail screen with:
  - title
  - description
  - play/resume/restart actions
  - back action
- Added a subtle branded watermark in the background using the Secret Shows logo.
- Tuned the watermark placement to the bottom-right at 10% opacity.

## Playback

- Added native full-screen playback using `AVPlayerViewController`.
- Built playback sessions around a `PlayerSession` object so the app can preserve playback state and save progress.
- Added resume support from saved local playback position.
- Added restart behavior that clears prior saved progress before starting over.

## Watch Progress

- Implemented a hybrid-ready watch progress model with local persistence only for now.
- Added per-show progress storage in `UserDefaults`.
- Added automatic migration support from the older simple `[showID: time]` progress format.
- Defined watch-progress rules:
  - started after more than 30 seconds watched
  - completed at 98% watched
- Added a thin green progress bar along the bottom edge of started cards.
- Added a green completed badge with a checkmark for finished shows.
- Configured completed shows to start fresh when replayed later.
- Added a `lastUpdatedAt` timestamp to persisted progress records so `Continue Watching` content can be ordered by most recently watched.

## Navigation and Focus

- Added tvOS-specific back-button behavior:
  - back from detail returns to the library
  - back from a focused grid item shifts focus to the `Log Out` button
  - back from `Log Out` exits normally
- Preserved the normal tvOS “hold back to exit” behavior by not over-intercepting system exit.
- Added focus restoration intent so returning from a detail screen targets the previously selected card.
- Continued refining focus restoration behavior on the library grid.
- Replaced the default tvOS button lift on library cards with a custom focusable card treatment so selection no longer grows far past the card bounds.
- Added deep-link handling for `njtv://show/<id>` so Top Shelf content can route directly into show detail screens.

## Secret Shows API and Caching

- Added automatic Secret Shows refresh when the app becomes active so new episodes appear without logging out and back in.
- Added URL normalization for older `iframe.mediadelivery.net` video links by rewriting them to CDN playlist URLs.
- Added shared cached Secret Shows storage for app-extension use.

## Top Shelf Extension

- Added a new `NewsJunkieTopShelf` extension target backed by `TVServices`.
- Shared session, playback progress, device ID, and cached Secret Shows data through the `group.com.thenewsjunkie.tv` App Group.
- Built Top Shelf content generation around the newest available show plus a `Continue Watching` section ordered by recent playback activity.
- Added deep-link actions from Top Shelf cards into the tvOS app.
- Added fallback Top Shelf artwork using bundled Secret Shows placeholder art when poster URLs are missing or malformed.
- Rendered fallback Top Shelf artwork into a padded 16:9 canvas so it fits `.hdtv` cards more predictably.

## Build and Environment Configuration

- Added app and extension entitlements for the shared App Group.
- Added a real app `Info.plist` with the `njtv` URL scheme registration.
- Added shared Xcode configs for dev/live server switching:
  - `Config/Debug-Dev.xcconfig`
  - `Config/Debug-Live.xcconfig`
  - `Config/Release.xcconfig`
- Added shared schemes for server switching:
  - `SS- tvOS Dev`
  - `SS- tvOS Live`
- Updated launch behavior so the selected scheme controls the API base URL for both the main app and the Top Shelf extension.

## Branding and Assets

- Added branded assets for:
  - Secret Shows placeholder art
  - Secret Player login image
  - splash video resource
- Updated app icon and top shelf image assets in the tvOS asset catalog.

## Documentation and Portability

- Created this changelog as a durable record of the tvOS R&D pass.
- Created `appguide.md` to document app architecture, UI behavior, API contracts, and portability guidance for future clients such as Fire TV and LG webOS.
