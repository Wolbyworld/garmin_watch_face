# Contributing

Thanks for your interest in improving the watch face! This doc covers the practical bits of getting set up and contributing a change.

## Getting set up

See [`docs/BUILD.md`](docs/BUILD.md) for the full dev environment — SDK install, signing key, and running the simulator.

## Development workflow

1. Fork + clone the repo.
2. Create a feature branch: `git checkout -b feature/my-change`.
3. Run `./preview.sh fenix847mm` to build and push to the simulator. A screenshot lands at `screenshots/latest.png`.
4. Iterate. The [`CLAUDE.md`](CLAUDE.md) at the repo root has detailed layout zones and a crop-zoom protocol (`sips -c`) for verifying specific UI areas.
5. Test at multiple activity levels (see "Multi-value testing" in `CLAUDE.md`) when changing anything that depends on steps, floors, HR, or Body Battery.
6. Before opening a PR, also build for `fenix6s` and sanity-check the MIP layout — the 240×240 display has its own simplified rendering path.

## Code style

- **Monkey C** — match the existing style in `source/`. Type annotations are generally avoided except on HTTP callbacks, where SDK 8.4.0+ requires them.
- **No hardcoded screen dimensions.** Use `dc.getWidth()` / `dc.getHeight()` and proportional layout helpers in `Theme.mc`.
- **Colors and spacing** belong in `Theme.mc`. Don't scatter hex literals across the view code.
- **Settings** go through `Settings.mc` — add a typed getter alongside the new property.

## Before submitting a PR

- [ ] `DEBUG_SIMULATOR = false` in `WatchFaceView.mc` (mandatory — never merge with it on)
- [ ] Built cleanly for both `fenix847mm` (AMOLED) and `fenix6s` (MIP)
- [ ] Screenshots attached for any visible change, ideally showing before/after
- [ ] No new hardcoded colors outside `Theme.mc`
- [ ] No new personal fallback data (location, timezone defaults) — make it configurable

## Reporting bugs

Open an issue with:
- Device model + firmware version
- Watch face version (or commit SHA)
- Reproduction steps
- A photo or screenshot if the issue is visual

## Feature requests

Open an issue labelled `enhancement`. Include a mockup or reference image if the request is about a visual change — it makes the conversation much faster.
