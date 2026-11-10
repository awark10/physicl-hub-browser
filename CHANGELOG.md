# Changelog

## 1.2.11

- The top bar buttons take their file from their Hub card (library Ext1, a0299616-...): the published card with the same title (Camera, Sun, EXT_Preset, Day_Light_System). Replacing the file on the card updates the button for everybody, and the new Drive id also refreshes the local package cache. The built-in Drive ids stay as a fallback (no connection, or no such card, e.g. Render preset PUB).

## 1.2.10

- The setup script gets the nodes just merged (global PHB_mergedNodes), so Add Day Light configures the new Daylight even when the scene already has another one. Needs the updated Sim_Day_Light.zip on Drive (its setup script reads PHB_mergedNodes).

## 1.2.9

- Add Day Light in a scene without LIGHT / LIGHT_GRP / ROOM_LIGHT: the lights stay at the top (Compass001 > Daylight001 > Sun001, sky); the helpers are no longer created. With the helpers present, the lights go under ROOM_LIGHT as before.

## 1.2.8

- Only the Add Day Light button (marked #script in tools) runs its package's setup script; Hub cards and the other buttons never run scripts.
- Add Day Light reuses the scene's LIGHT / LIGHT_GRP / ROOM_LIGHT / NIGHT_LIGHT helpers instead of merging copies (LIGHT001...); missing ones come from the package or are created by the script.
- Objects deleted by the setup script are skipped afterwards (no "deleted scene object" error).

## 1.2.7

- Add Day Light: a fifth top bar button imports the Daylight + VRayDome lighting package (Day_Light_System card: Compass001, Daylight001, Sun001 as VRaySun, VRayLight sky). The sun parameters, Environment Map = None, parenting under ROOM_LIGHT and disabling of other VRaySuns are done by the package's own `Sim_Day_Light_setup.ms`.
- Packages can now ship a post-setup script: after the merge the hub runs the first `*.ms` found in the package (`PHB_importBackground`). Packages without an .ms (backgrounds, decals, Camera, Sun) behave as before.
- The search box leaves room for the fifth button.

## 1.2.6

- Materials gets a Floor category (a Hub folder outside Library > Textures, listed after the Textures subfolders). A library can now mix parent folders and fixed folders in its category list.

## 1.2.5

- Fix "Syntax error: at tool, expected name" when opening the dialog: `tool` is a reserved word in MAXScript and can't be a variable name.

## 1.2.4

- Add Render preset EXTR and Add Render preset PUB work: each downloads its V-Ray preset (.rps) from Google Drive and loads it into the render settings, then reports the preset and the renderer (with a warning if it is not V-Ray).

## 1.2.3

- Add Sun works the same way as Add Camera: it imports the Physicl sun package from Google Drive.

## 1.2.2

- Add Camera works: it downloads the Physicl camera package from Google Drive and imports it like a Hub card. The top bar buttons are defined in `tools` in PHB_Client.ms.

## 1.2.1

- Search covers the whole Hub, not just the selected sidebar item: the first search loads every card list (once per session), results show their source ("Materials > Roof") and live filtering follows as you type. Previews are downloaded only for matches. Clearing the search or clicking the sidebar returns to the selected library.

## 1.2.0

- New layout: a library sidebar on the left replaces the tab row. Backplates, Decals, Models (Buildings, Grass, Hedges) and Materials (categories from the Hub) — clicking a library shows all of it and opens its sub-items, clicking a sub-item shows that category.
- Textures is now called Materials; the Category dropdown is gone (categories live in the sidebar).
- Search box with Find at the top right: filters the gallery by name as you type.
- Tool buttons Add Camera, Add Sun, Add Render preset EXTR, Add Render preset PUB (placeholders, "coming soon").
- Grass and hedges are separate categories under Models.

## 1.1.6

- The installer registers the macro in the running 3ds Max (fileIn of the .mcr instead of macros.load, which takes a folder), so "Hub Browser" appears in Customize User Interface right after the first install, without a restart.

## 1.1.5

- Fix the .mzp install ("Bad number or time syntax" in mzp.run): the version is now part of the package name.

## 1.1.4

- Cards whose title has characters not allowed in file names (e.g. "Dark Red / Brown Brick") now get their preview and can be imported; those characters become "_" in cache file names.

## 1.1.3

- .mzp package for distribution (`build_mzp.ps1` builds `dist/PhysiclHubBrowser_v<version>.mzp`).

## 1.1.2

- Fix "Bad free thunk local member index" error when previews were downloaded (opening a tab with new thumbnails).

## 1.1.1

- The dialog title shows the full version (v1.1.1); it is bumped with every change from now on.
- A tab whose settings changed (e.g. Textures after a reinstall) loads again instead of showing what was kept in memory in the same 3ds Max session.

## 1.1

- New tabs Grass, Buildings & Parts, Textures. Grass loads two Hub folders into one gallery, Buildings & Parts one.
- Textures tab with a category list; the categories are the subfolders of Library > Textures, read from the Hub, so new ones appear without a script update.
- Missing previews download 8 at a time over one reused connection (much faster first opening).
- Toolbar category renamed to PHYSICL.
- Larger dialog (1296x996, shrinks to fit smaller screens) and gallery thumbnails (307x172, three evenly spaced columns); the gallery is owner-drawn so thumbnails can exceed 256 px.
- Every import ends with one window saying what was imported (objects, textures, missing textures) or why it failed.

## 1.0

- Initial release, based on Backrounder v2.2.
