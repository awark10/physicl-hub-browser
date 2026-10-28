-- Physicl Hub Browser UI: Knowledge Hub login, gallery and import.
-- Evaluated at global scope by the macroScript (PhysiclHubBrowser.mcr); needs PHB_Client.ms loaded first.

-- Shown in the dialog title; bumped with every change (keep the installer's version in step)
global PHB_version = "1.2.3"

global PHB_kh
global PHB_items = #() -- #(title, previewFileId, packageFileId)
global PHB_loginOk = false
global PHB_library -- index into PHB_kh.libraries; kept between openings
if PHB_library == undefined do PHB_library = 1
global PHB_mainRollout
-- Per library: #(items, thumbnails, settings). Filled on first visit, reused on library switches and
-- reopenings, rebuilt by Refresh or when the library's settings in PHB_Client.ms changed (reinstall).
global PHB_cache
if PHB_cache == undefined do PHB_cache = #()
global PHB_loginRollout
global PHB_category -- per library: selected entry of the category list (1 = All)
if PHB_category == undefined do PHB_category = #()
global PHB_catLists -- per library: categories read from the Hub, #(#(name, folderId), ...)
if PHB_catLists == undefined do PHB_catLists = #()

-- Categories of library i: read from the Hub if it has a category parent folder (Materials),
-- otherwise its fixed list (Models), empty for the others
fn PHB_categoriesFor i = (
    if PHB_kh.categoryParentOf i != undefined and PHB_catLists[i] != undefined \
        then PHB_catLists[i] else PHB_kh.categoriesOf i
)
fn PHB_libCategories = PHB_categoriesFor PHB_library

-- ============================
-- IMPORT
-- ============================

-- Copies every bitmap the merged objects use into <scene folder>\textures\ as
-- <sceneName>-<original file name> and relinks the maps to the copies.
-- Returns #(number of textures copied, names of textures not found)
fn PHB_localizeTextures objs packageDir = (
    local dstDir = maxFilePath + "textures\\"
    if not doesDirectoryExist dstDir do makeDir dstDir
    local sceneName = getFilenameFile maxFileName

    local packageFiles = PHB_kh.findFiles packageDir "*.*"
    local copied = #() -- source file name (lowercase) -> destination
    local copiedDst = #()
    local missing = #()

    local mats = #()
    for o in objs where o.material != undefined do appendIfUnique mats o.material

    for mat in mats do (
        for map in (getClassInstances BitmapTexture target:mat) where map.filename != undefined and map.filename != "" do (
            local fName = filenameFromPath map.filename
            local key = toLower fName
            local idx = findItem copied key
            if idx == 0 do (
                -- Prefer the copy shipped in the package; fall back to the stored path
                local src = undefined
                for p in packageFiles while src == undefined do
                    if toLower (filenameFromPath p) == key do src = p
                if src == undefined and doesFileExist map.filename do src = map.filename

                if src == undefined then (
                    appendIfUnique missing fName
                ) else (
                    local dst = dstDir + sceneName + "-" + fName
                    if doesFileExist dst do deleteFile dst
                    if copyFile src dst then (
                        append copied key
                        append copiedDst dst
                        idx = copied.count
                    ) else (
                        format "Physicl Hub Browser: failed to copy % -> %\n" src dst
                        appendIfUnique missing fName
                    )
                )
            )
            if idx > 0 do map.filename = copiedDst[idx]
        )
    )
    for d in copiedDst do format "Physicl Hub Browser: texture %\n" d
    #(copiedDst.count, missing)
)

-- One window per import: this on failure, the summary at the end of PHB_importBackground on success
fn PHB_importFailed title reason = (
    messageBox ("Import failed: " + title + "\n" + reason) title:"Physicl Hub Browser"
    false
)

fn PHB_importBackground item = (
    local title = item[1]
    if maxFilePath == "" do
        return PHB_importFailed title "Please save the scene first: textures are copied next to the .max file."

    progressStart ("Downloading " + title + "...")
    local dir = PHB_kh.getPackage title item[3]
    progressEnd()
    if dir == undefined do
        return PHB_importFailed title PHB_kh.lastError

    local maxFiles = PHB_kh.findFiles dir "*.max"
    if maxFiles.count == 0 do
        return PHB_importFailed title "The package has no .max file."
    local maxFile = maxFiles[1]
    for f in maxFiles where matchPattern (getFilenameFile f) pattern:(title + "*") do (maxFile = f; exit)

    -- Merge the object(s) named after the background, or everything if none match
    local names = getMAXFileObjectNames maxFile
    local toMerge = for n in names where matchPattern n pattern:(title + "*") collect n
    if toMerge.count == 0 do toMerge = names

    try (
        mergeMAXFile maxFile toMerge #select #autoRenameDups
    ) catch (
        return PHB_importFailed title (getCurrentException())
    )
    local objs = selection as array
    if objs.count == 0 do
        return PHB_importFailed title "No objects were merged from the package."

    local tex = PHB_localizeTextures objs dir
    local missing = tex[2]
    -- Leave the imported object(s) selected so they can be placed right away
    select (for o in objs where isValidNode o collect o)
    completeRedraw()
    format "Physicl Hub Browser: imported % (% objects)\n" title objs.count

    local msg = "Imported: " + title + "\n" + objs.count as string + " objects, " + tex[1] as string + " textures"
    if missing.count > 0 do (
        msg += "\n\nThese textures were not found:\n"
        for m in missing do msg += m + "\n"
    )
    messageBox msg title:"Physicl Hub Browser"
    true
)

-- ============================
-- ROLLOUT: Login
-- ============================
rollout PHB_loginRollout "Knowledge Hub Login" width:300 height:190
(
    label lblInfo "Sign in with your kh-physicl.com account" pos:[15,12]
    label lblEmail "Email" pos:[15,40]
    dotNetControl tbEmail "System.Windows.Forms.TextBox" pos:[80,37] width:205 height:20
    label lblPass "Password" pos:[15,68]
    dotNetControl tbPass "System.Windows.Forms.TextBox" pos:[80,65] width:205 height:20
    checkbox chkRemember "Remember me on this computer" pos:[80,94] checked:true
    label lblError "" pos:[15,118] width:270 height:28
    button btnLogin "Sign in" pos:[80,150] width:100 height:26
    button btnCancel "Cancel" pos:[185,150] width:100 height:26

    fn doLogin = (
        local email = trimLeft (trimRight tbEmail.Text)
        if email == "" or tbPass.Text == "" do (lblError.text = "Enter email and password."; return false)
        lblError.text = "Signing in..."
        if PHB_kh.login email tbPass.Text remember:chkRemember.checked then (
            PHB_loginOk = true
            tbPass.Text = ""
            destroyDialog PHB_loginRollout
        ) else (
            lblError.text = PHB_kh.lastError
            tbPass.Text = ""
        )
    )

    on PHB_loginRollout open do (
        tbPass.UseSystemPasswordChar = true
        tbEmail.Focus()
    )
    on tbPass KeyDown s e do (
        if e.KeyCode == (dotNetClass "System.Windows.Forms.Keys").Enter do doLogin()
    )
    on btnLogin pressed do doLogin()
    on btnCancel pressed do destroyDialog PHB_loginRollout
)

-- Shows the login dialog until the user signs in or cancels
fn PHB_ensureLogin = (
    PHB_loginOk = false
    createDialog PHB_loginRollout modal:true
    PHB_loginOk
)

-- Frees the thumbnail bitmaps of a PHB_cache entry (an older install kept an ImageList there)
fn PHB_disposeThumbs entry = (
    if entry != undefined and classOf entry[2] == Array do
        for b in entry[2] do try (b.Dispose()) catch ()
)

-- Loads the current library into PHB_items, asking to sign in when the session is missing or expired.
-- Uses the in-memory copy unless force:true (Refresh).
fn PHB_loadLibrary force:false = (
    local cached = PHB_cache[PHB_library]
    local settings = PHB_kh.libraries[PHB_library] as string
    if not force and cached != undefined and cached.count >= 3 and cached[3] == settings do (
        PHB_items = cached[1]
        return true
    )
    -- Categories from the subfolders of a parent folder, read again on every load/Refresh
    local parent = PHB_kh.categoryParentOf PHB_library
    if parent != undefined do (
        local s = PHB_kh.fetchSubfolders parent
        if s[1] == #unauthorized do (
            if not (PHB_ensureLogin()) do return false
            s = PHB_kh.fetchSubfolders parent
        )
        if s[1] != #ok do (
            messageBox ("Could not load the categories:\n" + (if PHB_kh.lastError != "" then PHB_kh.lastError else "Session expired")) title:"Physicl Hub Browser"
            return false
        )
        local names = #()
        for c in s[2] do append names c[1]
        format "Physicl Hub Browser: % categories in %: %\n" s[2].count parent names
        -- No subfolders found (or the page changed): use the parent folder itself
        PHB_catLists[PHB_library] = if s[2].count > 0 then s[2] else #(#(PHB_kh.libraries[PHB_library][1], parent))
    )
    local folders = PHB_kh.foldersOf PHB_library cats:(PHB_libCategories())
    if folders.count == 0 do (
        -- Section without a Hub folder yet: nothing to fetch
        PHB_items = #()
        PHB_cache[PHB_library] = #(PHB_items, undefined, settings)
        return true
    )
    -- Several folders are shown as one gallery, folder by folder; each item remembers its
    -- category (item[4]) for the category list
    local items = #()
    local errors = ""
    local loaded = 0
    for f in folders do (
        local r = PHB_kh.fetchCards f[1]
        if r[1] == #unauthorized do (
            if not (PHB_ensureLogin()) do return false
            r = PHB_kh.fetchCards f[1]
        )
        if r[1] == #ok then (
            format "Physicl Hub Browser: % folder %: %\n" PHB_kh.libraries[PHB_library][1] f[1] PHB_kh.lastStats
            for it in r[2] do append items (append it f[2])
            loaded += 1
        ) else errors += (if PHB_kh.lastError != "" then PHB_kh.lastError else "Session expired") + "\n"
    )
    if errors != "" do
        messageBox ("Could not load the library:\n" + errors) title:"Physicl Hub Browser"
    if loaded == 0 do return false
    PHB_items = items
    PHB_disposeThumbs PHB_cache[PHB_library]
    PHB_cache[PHB_library] = #(PHB_items, undefined, settings) -- thumbnails are (re)built by fillList
    true
)

-- Downloads the previews of items that are not on disk yet, 8 at a time.
-- Kept outside the rollout with plain loops: nested for/collect over locals inside a rollout
-- function fails in 3ds Max 2022 ("Bad free thunk local member index").
fn PHB_downloadPreviews items = (
    local jobs = #()
    local p, first, last, batch, cancelled
    for it in items where it[2] != undefined do (
        p = PHB_kh.previewPath it[1] it[2]
        if not doesFileExist p do append jobs #(PHB_kh.previewUrl it[2], p)
    )
    if jobs.count == 0 do return ok
    progressStart ("Downloading " + jobs.count as string + " previews...")
    first = 1
    cancelled = false
    while first <= jobs.count and not cancelled do (
        last = amin (first + 7) jobs.count
        batch = #()
        for j = first to last do append batch jobs[j]
        PHB_kh.downloadMany batch
        cancelled = not (progressUpdate (100.0 * last / jobs.count))
        first = last + 1
    )
    progressEnd()
)

-- ============================
-- ROLLOUT: Main UI
-- ============================
-- Sized for a 2560x1440 screen (about 1030 px tall with the title bar).
rollout PHB_mainRollout "Physicl Hub Browser" width:1296 height:996
(
    -- Gallery thumbnail size (16:9). The gallery is owner-drawn because a .NET ImageList
    -- cannot hold images wider than 256 px; the ImageList only sizes the cells.
    local thumbW = 301
    local thumbH = 169
    local thumbs = #() -- Bitmaps of the library on screen, same order as PHB_items
    local shown = #() -- PHB_items indices of the gallery entries (selected category)
    local galleryItems = #() -- item arrays of the gallery entries, in list order
    local galleryThumbs = #() -- their bitmaps, same order
    local searching = false -- the gallery shows search results from the whole Hub
    local allLists = false -- the card lists of every library are in memory (search can run live)
    local pool -- thumbnails made for search results: preview path -> Bitmap
    local sideW = 200 -- width of the library sidebar


    -- Positions below are for the full 1296x996 size; layout moves them for smaller screens
    dotNetControl lblTitle "System.Windows.Forms.Label" pos:[10,8] width:200 height:30
    button btnTool1 "Add Camera" pos:[230,8] width:100 height:28
    button btnTool2 "Add Sun" pos:[336,8] width:100 height:28
    button btnTool3 "Add Render preset EXTR" pos:[442,8] width:170 height:28
    button btnTool4 "Add Render preset PUB" pos:[618,8] width:170 height:28
    dotNetControl tbSearch "System.Windows.Forms.TextBox" pos:[990,11] width:200 height:22
    button btnFind "Find" pos:[1196,8] width:90 height:28
    dotNetControl tvLib "System.Windows.Forms.TreeView" pos:[10,44] width:200 height:882
    dotNetControl lvBackgrounds "System.Windows.Forms.ListView" pos:[220,44] width:1066 height:882
    label lblStatus "" pos:[220,932] width:240
    button btnRefresh "Refresh" pos:[220,949] width:96 height:31
    button btnImport "IMPORT SELECTED" width:240 height:48 pos:[633,937]
    button btnLogout "Sign out" pos:[1190,949] width:96 height:31

    -- Fits the controls to the dialog size picked by PHB_dialogSize. Fewer rows show on a lower
    -- screen; on a narrower one the thumbnails shrink so a row still holds three.
    fn layout w h = (
        local listX = sideW + 20
        local listW = w - listX - 10
        local listH = h - 114
        tvLib.height = listH
        lvBackgrounds.width = listW
        lvBackgrounds.height = listH
        local y = 44 + listH
        lblStatus.pos = [listX, y + 6]
        btnRefresh.pos = [listX, y + 23]
        btnImport.pos = [listX + (listW - 240) / 2, y + 11]
        btnLogout.pos = [w - 106, y + 23]
        btnFind.pos = [w - 100, 8]
        -- The search box takes what is left right of the tool buttons (up to 200 px)
        local searchW = amax 100 (amin 200 (w - 106 - 798))
        tbSearch.width = searchW
        tbSearch.pos = [w - 106 - searchW, 11]
        local scrollW = (dotNetClass "System.Windows.Forms.SystemInformation").VerticalScrollBarWidth
        thumbW = amin 301 ((listW - 6 - scrollW) / 3 - 40)
        thumbH = thumbW * 9 / 16
    )

    fn makeThumb file = (
        -- Read through a stream so the cached file is not locked while the dialog is open.
        -- Fit inside thumbW x thumbH keeping the aspect ratio (decals are mostly square, backgrounds wide).
        local fs = (dotNetClass "System.IO.File").OpenRead file
        local img = (dotNetClass "System.Drawing.Image").FromStream fs
        local bmp = dotNetObject "System.Drawing.Bitmap" thumbW thumbH
        local gfx = (dotNetClass "System.Drawing.Graphics").FromImage bmp
        gfx.Clear ((dotNetClass "System.Drawing.Color").FromArgb 40 40 40)
        local s = amin ((thumbW as float) / img.Width) ((thumbH as float) / img.Height)
        local w = (img.Width * s) as integer
        local h = (img.Height * s) as integer
        gfx.DrawImage img ((thumbW - w) / 2) ((thumbH - h) / 2) w h
        gfx.Dispose()
        img.Dispose()
        fs.Close()
        bmp
    )

    fn grayThumb = (
        local bmp = dotNetObject "System.Drawing.Bitmap" thumbW thumbH
        local gfx = (dotNetClass "System.Drawing.Graphics").FromImage bmp
        gfx.Clear ((dotNetClass "System.Drawing.Color").Gray)
        gfx.Dispose()
        bmp
    )

    -- Three equal columns across the list (LVM_SETICONSPACING); without it Windows packs the
    -- icons to the left. Set again after every image list change, which resets the spacing.
    fn setIconSpacing = (
        try (
            local hwnd = lvBackgrounds.Handle
            if classOf hwnd == dotNetObject do hwnd = hwnd.ToInt64()
            local scrollW = (dotNetClass "System.Windows.Forms.SystemInformation").VerticalScrollBarWidth
            local cx = (lvBackgrounds.Width - 6 - scrollW) / 3
            local cy = thumbH + 44
            windows.sendMessage hwnd 0x1035 0 (cy * 65536 + cx)
        ) catch (
            format "Physicl Hub Browser: could not set the gallery spacing: %\n" (getCurrentException())
        )
    )

    -- ============================
    -- Sidebar: one node per library, child nodes for its categories (Models > Buildings...)
    -- Node.Tag = "library,category": category 0 = the library itself (all of it)
    -- ============================

    fn nodeText name hasChildren expanded = (
        if not hasChildren then name else ((if expanded then "v " else "> ") + name)
    )

    -- (Re)creates the child nodes of library i from its categories; keeps the node's expanded state
    fn fillChildren node i = (
        local cats = PHB_categoriesFor i
        node.Nodes.Clear()
        for c = 1 to cats.count do (
            local child = node.Nodes.Add cats[c][1]
            child.Tag = (i as string) + "," + (c as string)
        )
        -- Materials reads its categories from the Hub on first load; mark it as expandable before that
        local expandable = cats.count > 0 or PHB_kh.categoryParentOf i != undefined
        node.Text = nodeText PHB_kh.libraries[i][1] expandable node.IsExpanded
    )

    fn buildTree = (
        tvLib.BeginUpdate()
        tvLib.Nodes.Clear()
        for i = 1 to PHB_kh.libraries.count do (
            local node = tvLib.Nodes.Add PHB_kh.libraries[i][1]
            node.Tag = (i as string) + ",0"
            fillChildren node i
        )
        tvLib.EndUpdate()
    )

    -- Highlights the node of the current library and category
    fn selectNode = (
        local sel = PHB_category[PHB_library]
        local cat = if sel == undefined then 0 else sel - 1
        local node = tvLib.Nodes.Item[PHB_library - 1]
        if cat > 0 and cat <= node.Nodes.Count then (
            node.Expand()
            node.Text = nodeText PHB_kh.libraries[PHB_library][1] true true
            node = node.Nodes.Item[cat - 1]
        )
        tvLib.SelectedNode = node
    )

    -- Puts entries into the list: item arrays and bitmaps in list order, captions under the thumbnails
    fn fillGallery items bmps captions = (
        galleryItems = items
        galleryThumbs = bmps
        lvBackgrounds.Items.Clear()
        -- The ImageList only gives every cell its height; drawItem paints the thumbnails
        local imgList = dotNetObject "System.Windows.Forms.ImageList"
        imgList.ImageSize = dotNetObject "System.Drawing.Size" 256 thumbH
        lvBackgrounds.LargeImageList = imgList
        setIconSpacing()
        local lvi
        lvBackgrounds.BeginUpdate()
        for c in captions do (
            lvi = dotNetObject "System.Windows.Forms.ListViewItem" c
            lvi.ImageIndex = 0
            lvBackgrounds.Items.Add lvi
        )
        lvBackgrounds.EndUpdate()
    )

    -- Fills the list with the thumbnails of the selected library and category
    fn showItems = (
        local sel = PHB_category[PHB_library]
        local cat = if sel == undefined then 0 else sel - 1
        local items = #()
        local bmps = #()
        local captions = #()
        shown = #()
        for i = 1 to thumbs.count do
            if cat == 0 or PHB_items[i][4] == cat do append shown i
        for i in shown do (
            append items PHB_items[i]
            append bmps thumbs[i]
            append captions PHB_items[i][1]
        )
        fillGallery items bmps captions
        lblStatus.text = (shown.count as string) + " items"
    )

    -- ============================
    -- Search over the whole Hub
    -- ============================

    -- "Materials > Roof" for an item of library lib
    fn sourceName lib item = (
        local name = PHB_kh.libraries[lib][1]
        local cats = PHB_categoriesFor lib
        if item.count >= 4 and item[4] > 0 and item[4] <= cats.count do name += " > " + cats[item[4]][1]
        name
    )

    -- Loads the card lists of every library not in memory yet (lists only: thumbnails are made for
    -- search matches alone). Returns true when all of them are loaded.
    fn loadAllLists = (
        local prev = PHB_library
        local all = true
        local c, settings
        for lib = 1 to PHB_kh.libraries.count do (
            c = PHB_cache[lib]
            settings = PHB_kh.libraries[lib] as string
            if c == undefined or c.count < 3 or c[3] != settings do (
                PHB_library = lib
                if PHB_loadLibrary() then fillChildren (tvLib.Nodes.Item[lib - 1]) lib else all = false
            )
        )
        PHB_library = prev
        if PHB_cache[prev] != undefined do PHB_items = PHB_cache[prev][1]
        all
    )

    -- True when every library's card list is already in memory (e.g. from an earlier opening)
    fn listsInMemory = (
        local c
        for lib = 1 to PHB_kh.libraries.count do (
            c = PHB_cache[lib]
            if c == undefined or c.count < 3 or c[3] != (PHB_kh.libraries[lib] as string) do return false
        )
        true
    )

    -- Thumbnail of item idx of library lib: the library's own bitmaps when it has been opened,
    -- otherwise one made for a search (kept in pool while the dialog is open); undefined if none yet
    fn searchThumb lib idx = (
        local c = PHB_cache[lib]
        local item = c[1][idx]
        if lib == PHB_library and thumbs.count == PHB_items.count do return thumbs[idx]
        if classOf c[2] == Array and c[2].count == c[1].count and (c[2].count == 0 or c[2][1].Width == thumbW) do
            return c[2][idx]
        if item[2] == undefined do return undefined
        local p = PHB_kh.previewPath item[1] item[2]
        if hasDictValue pool p then pool[p] else undefined
    )

    -- Shows every card of every library whose name contains the search text.
    -- load:false (typing) only searches the lists already in memory.
    fn runSearch load:true = (
        local text = trimLeft (trimRight tbSearch.Text)
        if text == "" do return ok
        if load and not allLists do allLists = loadAllLists()
        if pool == undefined do pool = Dictionary #string
        local pattern = "*" + text + "*"
        local hits = #() -- #(library, index)
        local missing = #()
        local items = #()
        local bmps = #()
        local captions = #()
        local c, it, p, bmp
        for lib = 1 to PHB_kh.libraries.count do (
            c = PHB_cache[lib]
            if c != undefined do
                for i = 1 to c[1].count do
                    if matchPattern c[1][i][1] pattern:pattern do append hits #(lib, i)
        )
        -- Matches without a thumbnail yet: download the missing previews, then make the thumbnails
        for h in hits do (
            it = PHB_cache[h[1]][1][h[2]]
            if it[2] != undefined and searchThumb h[1] h[2] == undefined do append missing it
        )
        if missing.count > 0 do (
            PHB_downloadPreviews missing
            for m in missing do (
                p = PHB_kh.previewPath m[1] m[2]
                bmp = undefined
                if doesFileExist p do bmp = try (makeThumb p) catch (undefined)
                if bmp != undefined do pool[p] = bmp
            )
        )
        for h in hits do (
            it = PHB_cache[h[1]][1][h[2]]
            bmp = searchThumb h[1] h[2]
            append items it
            append bmps (if bmp != undefined then bmp else grayThumb())
            append captions (it[1] + "\n" + (sourceName h[1] it))
        )
        -- The sidebar is dimmed and has no selection while results are shown
        searching = true
        tvLib.SelectedNode = undefined
        tvLib.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 120 120 120
        fillGallery items bmps captions
        lblStatus.text = (hits.count as string) + " results"
    )

    -- Back to the selected sidebar item
    fn endSearch = (
        searching = false
        tvLib.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 220 220 220
        selectNode()
        showItems()
    )

    fn fillList = (
        lvBackgrounds.Items.Clear()
        local onHub = (PHB_kh.foldersOf PHB_library cats:(PHB_libCategories())).count > 0
        btnImport.enabled = onHub
        btnRefresh.enabled = onHub
        if not onHub do (
            thumbs = #()
            shown = #()
            galleryItems = #()
            galleryThumbs = #()
            lblStatus.text = "Coming soon"
            return ok
        )
        local cached = PHB_cache[PHB_library]
        -- Thumbnails kept from an earlier opening are reused only if they are bitmaps of the
        -- current size (an older install kept an ImageList there, or another size)
        local reuse = cached != undefined and classOf cached[2] == Array and cached[2].count == PHB_items.count \
            and (cached[2].count == 0 or cached[2][1].Width == thumbW)
        if reuse then thumbs = cached[2] else (
            PHB_disposeThumbs cached
            thumbs = #()
            PHB_downloadPreviews PHB_items
            progressStart ("Loading " + PHB_kh.libraries[PHB_library][1] + " from Knowledge Hub...")
            for i = 1 to PHB_items.count do (
                local item = PHB_items[i]
                -- A preview that failed to download (or was cancelled) shows as a gray tile until Refresh
                local file = if item[2] != undefined then PHB_kh.previewPath item[1] item[2] else undefined
                local thumb = undefined
                if file != undefined and doesFileExist file do thumb = try (makeThumb file) catch (undefined)
                append thumbs (if thumb != undefined then thumb else grayThumb())
                if not (progressUpdate (100.0 * i / PHB_items.count)) do exit
            )
            progressEnd()
            -- Keep them only if every thumbnail was made (not cancelled)
            if cached != undefined and thumbs.count == PHB_items.count do cached[2] = thumbs
        )
        showItems()
    )

    -- Owner draw: thumbnail centred in the cell, title below, blue background when selected
    fn drawItem e = (
        local g = e.Graphics
        local b = e.Bounds
        local color = dotNetClass "System.Drawing.Color"
        local back = if e.Item.Selected then color.FromArgb 70 110 170 else lvBackgrounds.BackColor
        local brush = dotNetObject "System.Drawing.SolidBrush" back
        g.FillRectangle brush b
        brush.Dispose()
        local x = b.X + (b.Width - thumbW) / 2
        local y = b.Y + 2
        local bmp = galleryThumbs[e.ItemIndex + 1]
        if bmp != undefined do g.DrawImage bmp x y thumbW thumbH
        local fmt = dotNetObject "System.Drawing.StringFormat"
        fmt.Alignment = (dotNetClass "System.Drawing.StringAlignment").Center
        fmt.Trimming = (dotNetClass "System.Drawing.StringTrimming").EllipsisCharacter
        local textBrush = dotNetObject "System.Drawing.SolidBrush" lvBackgrounds.ForeColor
        local rect = dotNetObject "System.Drawing.RectangleF" (b.X as float) ((y + thumbH + 4) as float) (b.Width as float) ((b.Bottom - y - thumbH - 4) as float)
        g.DrawString e.Item.Text lvBackgrounds.Font textBrush rect fmt
        textBrush.Dispose()
        fmt.Dispose()
        e.DrawDefault = false
    )

    -- Shows library i, category sel (1 = all of it), loading the library when it changes
    fn showSource i sel = (
        if i != PHB_library do (
            local prev = PHB_library
            PHB_library = i
            if not (PHB_loadLibrary()) do (
                PHB_library = prev
                selectNode()
                return false
            )
            PHB_category[i] = sel
            -- Categories read from the Hub (Materials) are known only now
            fillChildren (tvLib.Nodes.Item[i - 1]) i
            fillList()
            selectNode()
            return true
        )
        PHB_category[i] = sel
        showItems()
        selectNode()
        true
    )

    -- Click on a library: expand/collapse its categories and show all of it.
    -- Click on a category: show only that category.
    fn onNodeClick node = (
        -- A click in the sidebar leaves the search (TextChanged ends it)
        if tbSearch.Text != "" do tbSearch.Text = ""
        local parts = filterString (node.Tag as string) ","
        local i = parts[1] as integer
        local c = parts[2] as integer
        if c == 0 then (
            local wasExpanded = node.IsExpanded
            showSource i 1
            -- showSource may have rebuilt the children; read the node again
            local n = tvLib.Nodes.Item[i - 1]
            if n.Nodes.Count > 0 do (
                if wasExpanded then n.Collapse() else n.Expand()
                n.Text = nodeText PHB_kh.libraries[i][1] true n.IsExpanded
            )
            tvLib.SelectedNode = n
        ) else (
            -- showSource selects the category node (the clicked node may have been rebuilt)
            showSource i (c + 1)
        )
    )

    -- Top bar button t (PHB_kh.tools): imports its package like a Hub card, or "coming soon"
    fn runTool t = (
        local tool = PHB_kh.tools[t]
        if tool[3] == undefined then
            messageBox (tool[1] + ": coming soon.") title:"Physicl Hub Browser"
        else
            PHB_importBackground #(tool[2], undefined, tool[3])
    )

    fn importSelected = (
        if lvBackgrounds.SelectedItems.Count == 0 do (
            messageBox "Please select an item first." title:"Info"
            return false
        )
        local idx = (lvBackgrounds.SelectedItems.Item[0]).Index + 1
        PHB_importBackground galleryItems[idx]
    )

    on PHB_mainRollout open do (
        PHB_mainRollout.title = "Physicl Hub Browser v" + PHB_version
        try (layout PHB_mainRollout.width PHB_mainRollout.height) catch (
            format "Physicl Hub Browser: could not fit the dialog to the screen: %\n" (getCurrentException())
        )
        local drawingColor = dotNetClass "System.Drawing.Color"
        local dark = drawingColor.FromArgb 40 40 40
        local light = drawingColor.FromArgb 220 220 220
        -- The title label sits on the dialog itself, so it takes the dialog's (theme) background
        local bg = (colorMan.getColor #background) * 255
        lblTitle.BackColor = drawingColor.FromArgb (bg.x as integer) (bg.y as integer) (bg.z as integer)
        lblTitle.ForeColor = light
        lblTitle.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 13.0
        lblTitle.Text = "Knowledge Hub Library"
        -- Button captions come from PHB_kh.tools
        local toolButtons = #(btnTool1, btnTool2, btnTool3, btnTool4)
        for t = 1 to toolButtons.count do
            if t <= PHB_kh.tools.count do toolButtons[t].text = PHB_kh.tools[t][1]

        tvLib.BackColor = dark
        tvLib.ForeColor = light
        tvLib.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 12.0
        tvLib.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").None
        tvLib.ShowLines = false
        tvLib.ShowPlusMinus = false
        tvLib.ShowRootLines = false
        tvLib.FullRowSelect = true
        tvLib.HideSelection = false
        tvLib.Indent = 18
        tvLib.ItemHeight = 28

        lvBackgrounds.View = (dotNetClass "System.Windows.Forms.View").LargeIcon
        lvBackgrounds.MultiSelect = false
        lvBackgrounds.HideSelection = false
        lvBackgrounds.OwnerDraw = true
        lvBackgrounds.BackColor = dark
        lvBackgrounds.ForeColor = light

        buildTree()
        selectNode()
        fillList()
    )

    on PHB_mainRollout close do (
        -- Thumbnails made for search results belong to this dialog only
        if pool != undefined do for k in pool.keys do try (pool[k].Dispose()) catch ()
        pool = undefined
    )

    on tvLib NodeMouseClick s e do onNodeClick e.Node
    on btnTool1 pressed do runTool 1
    on btnTool2 pressed do runTool 2
    on btnTool3 pressed do runTool 3
    on btnTool4 pressed do runTool 4
    -- Typing searches live once every list is in memory; until then Enter or Find loads them
    on tbSearch TextChanged s e do (
        if trimLeft (trimRight tbSearch.Text) == "" then (if searching do endSearch())
        else (
            if not allLists do allLists = listsInMemory()
            if allLists do runSearch load:false
        )
    )
    on tbSearch KeyDown s e do (
        if e.KeyCode == (dotNetClass "System.Windows.Forms.Keys").Enter do (
            e.SuppressKeyPress = true
            runSearch()
        )
    )
    on btnFind pressed do (
        if trimLeft (trimRight tbSearch.Text) == "" then (if searching do endSearch()) else runSearch()
    )
    on btnRefresh pressed do (
        if tbSearch.Text != "" do tbSearch.Text = ""
        if PHB_loadLibrary force:true do (
            fillChildren (tvLib.Nodes.Item[PHB_library - 1]) PHB_library
            fillList()
            selectNode()
        )
    )
    on btnImport pressed do importSelected()
    on lvBackgrounds DoubleClick s a do importSelected()
    on lvBackgrounds DrawItem s e do (try (drawItem e) catch (e.DrawDefault = true))
    on btnLogout pressed do (
        PHB_kh.logout()
        PHB_items = #()
        destroyDialog PHB_mainRollout
        for c in PHB_cache do PHB_disposeThumbs c
        PHB_cache = #()
    )
)

-- Dialog size: 1296x996 where it fits, otherwise the work area (taskbar excluded) of the
-- monitor 3ds Max is on, minus a margin. Returns #(width, height) in dialog units.
fn PHB_dialogSize = (
    local w = 1296
    local h = 996
    try (
        local screenClass = dotNetClass "System.Windows.Forms.Screen"
        local scr = try (screenClass.FromHandle (dotNetObject "System.IntPtr" (windows.getMAXHWND()))) catch (screenClass.PrimaryScreen)
        local area = scr.WorkingArea
        local scale = try (GetUIScaleFactor()) catch (1.0)
        w = amin w (amax 700 ((area.Width / scale) as integer - 40))
        h = amin h (amax 500 ((area.Height / scale) as integer - 80))
    ) catch (
        format "Physicl Hub Browser: could not read the screen size: %\n" (getCurrentException())
    )
    #(w, h)
)

fn PHB_open = (
    -- A fresh client each time, so a reinstalled PHB_Client.ms takes effect without restarting Max
    PHB_kh = PHB_KHClient()
    PHB_kh.init()
    PHB_kh.loadSession()
    if PHB_library > PHB_kh.libraries.count do PHB_library = 1
    try (destroyDialog PHB_mainRollout) catch ()
    if PHB_loadLibrary() do (
        local size = PHB_dialogSize()
        createDialog PHB_mainRollout size[1] size[2]
    )
)
