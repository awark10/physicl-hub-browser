# Physicl Hub Browser

A 3ds Max 2022 plugin that shows the **Knowledge Hub** (kh-physicl.com) asset libraries as a
browsable gallery inside Max. Sign in with your Hub account, pick a library in the sidebar and an
item from the thumbnail grid, click **IMPORT SELECTED**, and it's downloaded, merged into the
current scene, and its textures are copied and relinked as the scene's own files.

Physicl Hub Browser started as a copy of [Backrounder](https://github.com/awark10/backrounder) v2.2
and continues from there as a separate project.

## Structure

| File | Role |
|---|---|
| `PhysiclHubBrowser.mcr` | macroScript `PhysiclHubBrowser` (category `PHYSICL`, "Hub Browser") — loads the two files below and opens the dialog |
| `PHB_Client.ms` | Knowledge Hub client — library list, login, session cookie, card list, subfolders, Drive downloads, cache, JSON reader |
| `PHB_UI.ms` | Login dialog, main dialog (library sidebar, tool buttons, search, gallery), import (merge + texture copy & relink) |
| `Install_PhysiclHubBrowser.ms` | Installer — copies the three files into `userMacros` and registers the macro in the running Max |
| `build_mzp.ps1` | Builds `dist\PhysiclHubBrowser_v<version>.mzp` |

## How it works

- **Login:** `POST /api/auth/login` with email and password; the Hub answers with a Supabase
  session cookie. With "Remember me" the cookie is saved to `Physicl_Hub_Browser_cache\session.dat`,
  encrypted per Windows user (DPAPI). The password is never stored.
- **Sidebar:** one entry per item of `libraries` in `PHB_Client.ms` (Backplates, Decals, Models,
  Materials). A library with categories has sub-items: clicking the library shows all of it and
  opens or closes the sub-items, clicking a sub-item shows only that category. Models has a fixed
  list (Buildings, Grass, Hedges); Materials takes its categories from the subfolders of
  Library > Textures on the Hub, read from that Hub page (`GET /library/<id>`, there is no JSON call
  for folders) on load and Refresh, so a new subfolder appears without a script update.
- **Library:** `GET /api/library/cards?folderId=…` for every folder of the library returns the
  cards as JSON; only `published` cards are shown. Each library is kept in memory between switches
  until **Refresh**. An expired session shows the login dialog again. A library entry without a
  folder shows "Coming soon".
- **Search:** the box at the top right searches the whole Hub by name. The first search (Enter or
  Find) loads the card lists of every library once per 3ds Max session; after that results update
  as you type. Results show where each card comes from ("Materials > Roof"), previews are
  downloaded only for matches, and the sidebar is dimmed while results are shown. Clearing the box
  or clicking a sidebar item goes back to the selected library.
- **Tool buttons:** each is an entry in `tools` in `PHB_Client.ms` (caption, item name, Drive id of a
  package zip). Add Camera imports the Physicl camera package like a Hub card (merge into the saved
  scene, textures copied and relinked, result window), and Add Sun does the same with the sun package.
  Add Render preset EXTR / PUB download a zip of V-Ray render presets and load its .rps into the
  production render settings (all categories); a warning follows if the renderer is not V-Ray (the
  Physicl spec: V-Ray 5.10.03, 3ds Max 2022.3).
- **Thumbnails:** Drive's server-side thumbnail (`drive.google.com/thumbnail?id=…&sz=w320`, ~60 KB)
  instead of the full preview (up to 100 MB), downloaded 8 at a time and cached in
  `Physicl_Hub_Browser_cache\thumbs`. The gallery is owner-drawn, three columns, sized to the screen.
- **Import:** requires a saved scene. Downloads the card's zip from Drive into
  `Physicl_Hub_Browser_cache\packages`, unpacks it, merges the objects named after the item (or
  the whole file), then copies every bitmap they use into `<scene folder>\textures\` as
  `<sceneName>-<original name>` and relinks the maps. The imported objects stay selected and a
  window reports what was imported. Cache file names include the Drive id, so a file replaced on
  the Hub is fetched again.

## Installation

Drag `PhysiclHubBrowser_v<version>.mzp` into the 3ds Max viewport (or Scripting → Run Script →
pick the .mzp). Without the package, run `Install_PhysiclHubBrowser.ms` from this folder the same
way. Then Customize → Customize User Interface → Toolbars → category `PHYSICL` → drag
"Hub Browser" to a toolbar. No restart is needed. A Knowledge Hub account is required.

To build the package: `powershell -ExecutionPolicy Bypass -File build_mzp.ps1` → `dist\`.

The installer only writes its own files; an existing Backrounder / Physicl Asset Browser install
is left as it is and can be removed by hand.

## Version

v1.2.5 — see [CHANGELOG.md](CHANGELOG.md).
