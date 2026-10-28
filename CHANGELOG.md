# Changelog

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
