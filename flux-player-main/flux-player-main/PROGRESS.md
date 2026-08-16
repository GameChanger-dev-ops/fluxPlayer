# Flux Player - Progress Log

## Status

| # | Step | Status |
|---|------|--------|
| 1 | flutter create scaffold | Partial (see decisions) |
| 2 | Dependencies in pubspec.yaml | Done |
| 3 | Drift schema + DAOs | Done (schema v1) |
| 4 | Design system (theme, colors, typography, GlassCard) | Done |
| 5 | GoRouter + placeholder screens | Done |
| 6 | Core data pipeline (scanner, matcher, TMDb) | Done, with unit tests |
| 7 | Player (media_kit, gestures, resume, 10s debounced writes) | Done |
| 8 | Library (grid, Continue Watching shelf, media cards) | Done |
| 9 | Smart organizer (5 modes, gap analyzer, sorting) | Done, with unit tests |
| 10 | Watch history + resume | Done |
| 11 | Subtitles (embedded, external auto-load, OpenSubtitles + 24h cache) | Done |
| 12 | Settings (all sections, secure API keys, theme switching) | Done |
| 13 | Platform-specific features | Partial: Windows title bar, tray, drag-drop done; Android/iOS config needs local `flutter create` (issue #8) |
| 14 | Widget tests | Done for GlassCard + MediaCard; screen-level tests in issue #9 |
| 15 | flutter analyze zero-warning pass | Requires local run (issue #9) |

## Decisions

1. **Platform folders**: `flutter create` cannot run in this environment. Run locally once:
   `flutter create . --org com.gamechanger --platforms android,ios,windows`
2. **Code generation**: run `dart run build_runner build --delete-conflicting-outputs`
   (Drift `database.g.dart`) and any build for l10n (`generate: true`).
3. **lucide_flutter**: published package is `lucide_icons_flutter`; adopted it.
4. **SharedAxisTransition**: from the `animations` package, wired via GoRouter
   `CustomTransitionPage` at 280ms horizontal.
5. **Fonts**: Inter / Playfair Display via `google_fonts` (runtime cached).
6. **TMDb enrichment** happens inline during scans when a key is configured;
   scans stay fully offline-capable otherwise.
7. **Gap analyzer UI panel**: service + tests complete; the dedicated panel UI
   ships with issue #4 alongside the grouped shelf layout.
8. **Subtitle styling** (font size, color, background opacity): size persisted in
   settings; applying to the media_kit renderer lands with issue #6 polish.

## Remaining work

- Platform specifics: Android PiP + foreground service, iOS AVAudioSession/AirPlay
  (AndroidManifest/Info.plist edits after local `flutter create`) (issue #8)
- Tray icon asset (`assets/tray_icon.ico`): add and register in pubspec;
  tray degrades gracefully and logs a warning until then
- Auto-play next episode + skip intro wiring in player (settings already persisted)
- Details screen with TMDb episode lists
- Widget tests + local `flutter analyze` zero-warning verification (issue #9)
