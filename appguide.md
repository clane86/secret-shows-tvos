# News Junkie Secret Shows tvOS App Guide

## Purpose

This document describes the structure, behavior, and backend communication model of the Apple TV version of News Junkie Secret Shows. It is written as a transfer document for future platform work, especially non-Apple clients such as Fire TV and LG webOS.

The current implementation is a native tvOS app written in SwiftUI with AVKit playback. Its main responsibilities are:

- authenticate the user against the News Junkie backend
- validate that the user is entitled to Secret Shows video access
- load the Secret Shows video catalog
- present a branded browsing experience optimized for remote navigation
- support play, resume, restart, and local watch-progress tracking

## Source Layout

The core application behavior lives primarily in one file:

- `News Junkie/ContentView.swift`

The app entry point lives here:

- `News Junkie/News_JunkieApp.swift`

The tvOS app currently centralizes most logic in `ContentView.swift`, including:

- screen routing
- UI view definitions
- state model
- API client
- persistence helpers
- playback session handling
- decoding helpers

This is acceptable for an R&D phase, but if the app is ported to Fire TV or LG webOS, the equivalent logic should be split into modules such as:

- `AppState`
- `AuthService`
- `CatalogService`
- `PlaybackService`
- `PersistenceStore`
- `UI Screens`

## Runtime Screen Flow

At launch, `News_JunkieApp` creates a single `AppModel` and injects it into the view tree.

`AppModel.Screen` drives the entire application state:

- `splash`
- `loading`
- `login`
- `accessDenied`
- `library`
- `detail`
- `error`

The high-level flow is:

1. App launches.
2. The app decides whether to show the splash based on a six-hour foreground interval.
3. The app attempts to restore a saved authenticated session.
4. If no session exists, it shows the login screen.
5. If a session exists, it fetches user entitlement data from the backend.
6. If the user is entitled, it fetches the Secret Shows catalog.
7. It then routes to either the library or the previously saved detail route.

## UI Structure and Visual Design

### 1. Splash Screen

The splash screen is implemented in `SplashScreen` and `SplashVideoPlayerView`.

Behavior:

- uses `NJ-TV-splash.mp4` if it exists in the app bundle
- otherwise falls back to a simple text-based splash
- can be skipped with a click/tap
- automatically advances when playback finishes

The splash is not the iOS-style launch screen. It is an in-app branded intro.

### 2. Login Screen

The login screen is implemented in `LoginScreen`.

Visual structure:

- large top-centered branded image from `SecretPlayerLogin`
- headline: `News Junkie Secret Shows`
- supporting text: `Sign in to browse and play Secret Shows videos.`
- email field
- password field
- red `Sign In` button

Notable visual choices:

- the old border treatment was removed from the text fields
- typed text changes color by focus state
- focused input text is dark for legibility on the lighter active field appearance
- unfocused input text is white for contrast against the darker background

This screen is intentionally sparse and television-friendly. It minimizes dense forms and places the visual emphasis on brand plus the primary sign-in action.

### 3. Library Screen

The library screen is implemented in `LibraryScreen` and `LibraryHeroHeader`.

Visual structure:

- top banner using `user_bg_image`
- circular profile image using `user_avatar_image`
- personalized greeting using `user_first_name`
- subtitle encouraging browsing
- top-right `Log Out` button
- poster grid of Secret Shows cards

The overall visual tone is a dark gradient background with white content, red action emphasis, and television-sized spacing.

The user greeting currently renders like:

`Hello, Chris!`

The subtitle currently renders like:

`Browse the Secret Shows video library...`

### 4. Grid Card Design

Each show card is implemented in `SecretShowCard`.

Current card structure:

- white poster rectangle
- centered branded Secret Shows placeholder image
- title below poster
- date at bottom-right of the card
- focused-card text becomes black for readability

Additional card metadata:

- a thin green progress bar appears at the bottom edge of the poster once the user has watched more than 30 seconds
- a green check badge appears in the top-right when the user completes 98% or more of the video

This structure is easy to replicate on other platforms:

- Fire TV: use a focusable card with scale/focus ring behavior
- LG webOS: use remote-focus cards with CSS transforms and a bottom overlay progress bar

### 5. Detail Screen

The detail screen is implemented in `SecretShowDetailScreen`.

Layout:

- large title
- long-form description text
- action buttons:
  - `Resume` and `Restart` if progress exists
  - otherwise `Play`
  - plus `Back`

Visual branding:

- a large Secret Shows logo watermark sits behind the content
- positioned bottom-right
- low-opacity at 10%

This gives the detail screen more character without reducing readability.

## Navigation Model

The tvOS build is remote-first and uses explicit back-button handling.

### Current Intended Behavior

- from detail screen, pressing back returns to the library
- from a focused library card, pressing back moves focus to `Log Out`
- from `Log Out`, pressing back exits the app normally
- holding back should continue to use the normal tvOS exit behavior

The app also keeps a `preferredLibraryFocusShowID` so that when the user returns from a detail screen, the previously selected show should regain focus on the grid. This behavior has been under active refinement and is important to preserve on any new platform.

Equivalent behavior on other platforms:

- Fire TV: map remote back to route stack navigation first, then exit behavior second
- LG webOS: map return/back keys the same way, preserving focused-card restoration

## Playback Model

Playback is implemented through:

- `PlayerSession`
- `PlayerView`
- `VideoPlayerControllerRepresentable`

Each `PlayerSession` owns:

- the `AVPlayer`
- the selected `SecretShow`
- the playback progress store

Behavior:

- `Play` starts from time `0`
- `Resume` starts from the saved local time
- `Restart` clears saved local progress first, then starts from `0`

The player periodically saves progress every 5 seconds. It also writes a completion record when playback reaches the end of the item.

For future Fire TV or webOS implementations, this logic should remain conceptually the same:

- create a per-show playback session
- seek to saved position on resume
- save progress on interval and on player close
- mark complete when near the end

## Watch Progress Rules

Watch progress is currently hybrid-ready but local-only. The storage layer can later be swapped to a backend sync service without changing the UI contract.

### Current Rules

- started threshold: more than 30 seconds watched
- completed threshold: 98% watched
- completed shows show a check badge
- started or completed shows show a bottom-edge progress bar
- completed shows do not offer resume; replaying starts fresh
- restarting a show explicitly clears old progress

### Local Storage Format

Progress is stored in `UserDefaults` using the key:

`tv.secretshows.playbackProgress`

The newer storage format is a JSON-encoded dictionary of show IDs to records containing:

- `lastWatchedTime`
- `duration`
- `isCompleted`

There is also compatibility handling for the older format:

- `[String: Double]`

That allows existing local progress to survive the migration.

## State and Persistence

The app uses several small storage helpers:

- `SessionStore`
- `NavigationStore`
- `PlaybackProgressStore`

### SessionStore

Stores authenticated session data using:

- `userID`
- `authKey`
- `email`

Storage key:

`tv.secretshows.session`

### NavigationStore

Stores the last route so the app can restore:

- library
- detail(showID)

Storage key:

`tv.secretshows.lastRoute`

### SplashPolicy

Stores the last foreground timestamp so the splash can be replayed only after six hours.

Storage key:

`tv.secretshows.lastForegroundDate`

### Last Email

The login form also remembers the last entered email:

Storage key:

`tv.secretshows.lastEmail`

## Backend Communication

The backend client is implemented as `APIClient`.

The app currently communicates with three primary backend actions:

- `user/login`
- `user/score`
- `secretshows`

These actions are sent through a shared request builder that appends the `action` query item to the API endpoint.

### Request Shape

The request code uses:

- a shared base URL
- a shared API path
- standard app/device headers
- a mix of authenticated and unauthenticated requests

The request builder injects headers such as:

- `X-DEVICETYPE`
- `X-DEVICEID`
- `X-APPVERSION`
- `X-APPKEY`

These are defined under `APIConfiguration`.

This means any future client should preserve the same header contract unless the backend is updated to accept a new platform profile.

### Example: Login

Login is performed with the action:

`user/login`

The current request body contains:

```json
{
  "user_email": "user@example.com",
  "user_password": "correct horse battery staple"
}
```

The login request does not require an authenticated session.

The client expects a response containing a user detail payload and also checks backend error structures such as:

- `error.message`
- `non_field_errors`

That second point matters because the backend can report wrong-password failures in `non_field_errors`, not only in a single top-level message field.

### Example: User Entitlement Fetch

After login or session restore, the app calls:

`user/score`

This endpoint is used to determine whether the user can enter the Secret Shows library.

The app currently uses the following fields from the payload:

- `subscriber`
- `isVideo`
- `isAudio`
- `IsSecretShowEnabled`
- `user_first_name`
- `user_bg_image`
- `user_avatar_image`

The user is allowed into the library only when:

- `subscriber == true`
- `isVideo == true`
- `IsSecretShowEnabled == true`

The other fields are used for personalization and branding.

### Example: Secret Shows Catalog Fetch

The app then calls:

`secretshows`

The response is decoded into `SecretShow` models. The app filters to video-capable entries only.

Important fields currently used by the app:

- `id`
- `Title`
- `Url`
- `videoUrl`
- `pubDate`
- `description`
- `SeeItNowNew`

Only shows with a valid `videoUrl` are displayed in the tvOS library grid.

## Defensive Decoding Strategy

The backend payloads are not treated as perfectly typed. The app includes flexible decoding helpers that are important to preserve in any port.

The current client tolerates:

- numbers delivered as strings
- strings delivered as numbers
- booleans delivered as:
  - `true` or `false`
  - `1` or `0`
  - `"yes"` or `"no"`
  - `"true"` or `"false"`

This is essential. A stricter client on another platform will likely fail against real-world backend responses unless it preserves the same tolerance.

## Specific Implementation Examples

### Example 1: Personalized Library Header

After `user/score` returns:

- `user_first_name` becomes the greeting name
- `user_bg_image` becomes the hero banner image
- `user_avatar_image` becomes the circular avatar

That means the backend is not only an entitlement source. It is also a branding/personalization source for the home screen.

### Example 2: Resume Playback

If a user watches 14 minutes of a show and exits:

- the player writes the elapsed time to `PlaybackProgressStore`
- the detail screen later switches from `Play` to `Resume` and `Restart`
- the grid card shows a green progress bar

If the user then chooses `Resume`, the player seeks to the stored timestamp before playback begins.

### Example 3: Completion

If a user watches at least 98% of a video:

- the show is marked completed
- the card shows the green check badge
- future playback starts from the beginning instead of offering resume

This behavior is intentionally designed for episodic video where “finished” should feel complete and clean.

## Porting Guidance for Fire TV and LG webOS

The key portability principle is to preserve the app contract, not the SwiftUI implementation.

### Preserve These Contracts

- same login flow
- same entitlement rules
- same catalog filtering rules
- same route model: splash -> login/loading -> library -> detail -> player
- same watch-progress rules
- same back-button behavior
- same personalized header semantics

### Fire TV Recommendations

- UI framework: native Android TV Compose or Leanback-style focus UI
- playback: ExoPlayer
- local persistence: SharedPreferences or Room
- remote input: map back events carefully to match tvOS behavior

Suggested modules:

- `AuthRepository`
- `CatalogRepository`
- `PlaybackProgressRepository`
- `AppViewModel`
- `PlayerCoordinator`

### LG webOS Recommendations

- UI framework: HTML/CSS/JavaScript app shell
- playback: platform video APIs
- local persistence: IndexedDB or local storage abstraction
- remote input: explicit focus management with a route-aware back stack

Suggested modules:

- `apiClient.js`
- `sessionStore.js`
- `navigationStore.js`
- `progressStore.js`
- `libraryView.js`
- `detailView.js`
- `playerController.js`

### What Not to Port Literally

Do not port these Apple-specific details directly:

- `SwiftUI`
- `AVPlayerViewController`
- `FocusState`
- `UIViewRepresentable`
- `AsyncImage`
- `UserDefaults`

Instead, port the behaviors:

- screen state machine
- backend action calls
- tolerant decoding
- playback persistence logic
- remote-navigation rules

## Recommended Next Architecture Step

Before starting a Fire TV or webOS build, extract this tvOS prototype into conceptual layers:

- presentation
- app state
- services
- storage
- backend models

The API contract and the UX decisions are already stable enough to reuse. The main work on another platform should be:

- implementing the platform-specific focus model
- implementing the platform-specific player integration
- preserving the same backend tolerance and playback rules

## Final Notes

This Apple TV build already functions as a strong reference client for other television platforms because it defines:

- the authentication flow
- the entitlement model
- the library and detail UX
- the player lifecycle
- the watch-progress behavior
- the branding system

For future ports, treat this document and the current `ContentView.swift` behavior as the product spec, even if the code organization changes significantly per platform.
