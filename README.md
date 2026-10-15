# Physicl Hub Browser

A 3ds Max 2022 plugin that shows the **Knowledge Hub** (kh-physicl.com) backplate and decal
libraries as a browsable gallery inside Max. Sign in with your Hub account, pick an item from the
thumbnail grid, click **IMPORT SELECTED**, and it's downloaded, merged into the current scene, and
its textures are copied and relinked as the scene's own files.

Physicl Hub Browser started as a copy of [Backrounder](https://github.com/awark10/backrounder) v2.2
and continues from there as a separate project.

## Structure

| File | Role |
|---|---|
| `PhysiclHubBrowser.mcr` | macroScript `PhysiclHubBrowser` (category `PHYSICL`, "Hub Browser") — loads the two files below and opens the dialog |
| `PHB_Client.ms` | Knowledge Hub client — login, session cookie, card list, Drive downloads, cache, JSON reader |
| `PHB_UI.ms` | Login dialog, gallery dialog (BACKPLATES / DECALS / GRASS / BUILDINGS & PARTS / TEXTURES tabs), import (merge + texture copy & relink) |
| `Install_PhysiclHubBrowser.ms` | Installer — copies the three files into `userMacros`, reloads the macro live |

## How it works

- **Login:** `POST /api/auth/login` with email and password; the Hub answers with a Supabase
  session cookie. With "Remember me" the cookie is saved to `Physicl_Hub_Browser_cache\session.dat`,
  encrypted per Windows user (DPAPI). The password is never stored.
- **Library:** `GET /api/library/cards?folderId=…` (folders "Exterior scene Backplates", "Decals", two Grass folders and "Buildings & Parts",
  picked with the tabs at the top of the dialog) returns the cards as JSON; only
  `published` cards are shown. Each library is kept in memory between tab switches until
  **Refresh**. An expired session shows the login dialog again.
- **Sections in progress:** TEXTURES is a tab with no Hub folder yet; it
  shows an empty gallery with "Coming soon" and makes no Hub requests. Each tab is an entry in
  `libraries` in `PHB_Client.ms`; setting its `folderId` there turns it into a working library.
  A tab can also list several folderIds (like GRASS); their cards are shown together.
- **Categories:** TEXTURES takes its categories from the subfolders of Library > Textures: on load and
  Refresh the tab reads the subfolder links from that Hub page (`GET /library/<id>`, there is no JSON call
  for folders), loads every subfolder, and a "Category" list above the gallery (All / one category) filters
  the thumbnails without new Hub requests.
- **Thumbnails:** Drive's server-side thumbnail (`drive.google.com/thumbnail?id=…&sz=w320`, ~60 KB)
  instead of the full preview (up to 100 MB), cached in `Physicl_Hub_Browser_cache\thumbs`.
- **Import:** requires a saved scene. Downloads the card's zip from Drive into
  `Physicl_Hub_Browser_cache\packages`, unpacks it, merges the objects named after the item (or
  the whole file), then copies every bitmap they use into `<scene folder>\textures\` as
  `<sceneName>-<original name>` and relinks the maps. The imported objects stay selected. Cache
  file names include the Drive id, so a file replaced on the Hub is fetched again.

## Installation

Run `Install_PhysiclHubBrowser.ms` via Scripting → Run Script. Then Customize → Customize User
Interface → Toolbars → category `PHYSICL` → drag "Hub Browser" to a toolbar. A Knowledge Hub
account is required.

The installer only writes its own files; an existing Backrounder / Physicl Asset Browser install
is left as it is and can be removed by hand.

## Version

v1.1.1 — see [CHANGELOG.md](CHANGELOG.md).
