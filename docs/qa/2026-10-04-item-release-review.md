# Item release review — 2026-10-04

## Scope

Review of the found-item system and its gallery integration in gameplay commit
`0a88322`. Tests used Godot 4.7.2, headless, at a fixed 60 FPS.

## Checks completed

Sixteen focused checks passed again on the completed, committed implementation:
`items`, `first_level`, `dog_follow`, `scent_priority`, `chase`, `clues`, `runlog`,
`pause`, `minimap`, `boot`, `memory_lifecycle`, `audio_cache`, `stealth_rules`,
`footsteps`, `police`, and `gallery`. `git diff --check` also passed.

The first item run timed out with a nil player access while another agent was editing
the implementation. A direct rerun and the later runner invocation both passed.
The final run on `0a88322` passed, including the corrected catalog selection.

These are functional regression checks, not a new browser performance or memory
benchmark. Physical mobile interaction and first-time-player balance remain untested.
The strengthened coffee check demonstrates that sneaking footsteps alert a nearby
cop with coffee and stay quiet without it. It exercises movement, but does not
independently measure the 25% speed increase against a timed baseline.

## Release finding

Resolved in `0a88322`: `Items.pick()` previously used `n * 7` modulo a seven-entry
weighted pool from level 4, repeating one entry. A stride of three now visits every
entry in each supported pool. The test checks 140 picks each on levels 4, 5 and 8:
all five kinds appear, with hoodies and extinguishers appearing twice as often as
the other kinds.

## Production artifact

The normal Web release export succeeded without script errors. The gameplay pack
SHA-256 is `ab3dc0762eed13061557b53fcf5ff17712c593a94a3e5c1853a6711ac096b74b`.
Documentation is excluded from the game pack. The gallery includes five rendered
item icons and passes the manifest/file consistency check.

Deployment uses the existing `deploy.sh` workflow. Verify that the GitHub Pages
build matches the new `gh-pages` commit, then compare the served pack and gallery
files with the exported artifacts. A matching download verifies publication;
browser startup and item interaction are separate checks.
