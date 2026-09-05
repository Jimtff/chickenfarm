# Chicken Farm

A unified Roblox interface for automating repetitive tasks in Chicken Farm.

## Features

- Automatically buy 1, 5, 25, or 100 chickens
- Automatically sell eggs based on the current multiplier
- Automatically upgrade process and purchase tiers
- Automatically claim the group reward
- Automatically collect cash
- Optional anti-AFK mode
- Stats page with current game values and eggs per second
- Small timing labels below each automation
- Saved settings, window position, and customizable UI hotkey
- Responsive, scrollable interface with mouse and touch support

## Usage

1. Run the script.
2. Enable the desired automations in the **Farm** tab.
3. Select the purchase amount using one of the four amount buttons.
4. Set the sell multiplier between **0.50x and 1.50x** with the slider.
5. View the current game values in the **Stats** tab.

The default hotkey for showing or hiding the interface is **Right Ctrl**. It can be changed under **Interface**. Press ESC to cancel while selecting a new hotkey.

## UI Buttons

- Minus: Minimize the window
- Plus: Restore the window
- X: Stop the script and cleanly disconnect all connections

## Settings

If the runtime supports readfile, writefile, and isfile, settings are stored in ChickenFarm_PlaceId.json. Without file support, the script still works, but settings only remain active for the current session.

## Performance Improvements

- Remote calls run independently and no longer block every automation.
- Duplicate remote calls of the same type cannot run simultaneously.
- Eggs are only sold when eggs are available.
- The expensive Rebirth progress search only runs in the Stats tab and at most once every ten seconds.
- Error warnings are throttled to prevent console spam.
- Visual stats updates pause while the interface is hidden or minimized.

## Errors and Game Updates

The status bar at the bottom displays successful actions, waiting states, and errors. If a required game object is missing at startup, the script stops with a clear warning.

Roblox games can change object names, UI paths, and remote calls at any time. These paths in main.lua may need to be updated after a game update.

## Version

Current version: **2.0.0**

### Changes in 2.0.0

- Completely redesigned and standardized interface
- Responsive scaling, scrolling, and touch support
- Multiplier slider with a disabled state when Auto Sell is off
- Visible status and error messages
- Clear stats page
- More reliable group reward timer
- Optimized Rebirth scan
- Non-blocking remote workers
- Settings validation and versioning
- Minimize and clean shutdown controls
