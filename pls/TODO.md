# Integration Tasks — All Complete ✓

## Path Fixes
- [x] Fix Minigame3 scene paths (scripts, scenes, assets need `Minigame3/` prefix)
- [x] Fix Minigame4 scene paths (need `Minigame4/` prefix)
- [x] Fix Minigame3 main.gd arrow_scene preload path

## Signal Integration (Win Condition)
- [x] Add game_was_won/game_was_lost signals to Minigame3 HUD
- [x] Add minigame_won signal to Minigame4 minigame_4.gd
- [x] Implement `_launch_minigame3()` and `_launch_minigame4()` in MainMenu.gd
- [x] Connect signals for proper win→narrative flow

## Background Fixes
- [x] Fix `bg_home_inside_old` path (original_home.png → original-home.png)
- [x] Add `bg_home` texture key (maps to Home.png)
- [x] Add `bg_plaza` texture key (maps to Ruined-Streets.png)

## Fade In/Out
- [x] Fade to black before launching all minigames
- [x] Fade from black when transitioning back to dialogue
- [x] Proper cleanup between minigame transitions

## Story Flow Verified
- [x] day1 → home → walk_streets → return_home → **MG1: Fundraiser**
- [x] MG1 won → after_fundraiser → djo_choice → fight → **MG3: Rhythmic Foundation**
- [x] MG3 won → minigame3_narrative → **MG4: Puzzle**
- [x] MG4 won → minigame4_narrative → celebration → day1_complete