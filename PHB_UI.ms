-- Physicl Hub Browser UI: Knowledge Hub login, gallery and import.
-- Evaluated at global scope by the macroScript (PhysiclHubBrowser.mcr); needs PHB_Client.ms loaded first.

-- Shown in the dialog title; bumped with every change (keep the installer's version in step)
global PHB_version = "1.1.6"

global PHB_kh
global PHB_items = #() -- #(title, previewFileId, packageFileId)
global PHB_loginOk = false
global PHB_library -- index into PHB_kh.libraries; kept between openings
if PHB_library == undefined do PHB_library = 1
global PHB_mainRollout
-- Per library: #(items, thumbnails, settings). Filled on first visit, reused on tab switches and
-- reopenings, rebuilt by Refresh or when the library's settings in PHB_Client.ms changed (reinstall).
global PHB_cache
if PHB_cache == undefined do PHB_cache = #()
global PHB_loginRollout
global PHB_category -- per library: selected entry of the category list (1 = All)
if PHB_category == undefined do PHB_category = #()
global PHB_catLists -- per library: categories read from the Hub, #(#(name, folderId), ...)
if PHB_catLists == undefined do PHB_catLists = #()

-- Categories of the current library: read from the Hub if it has a category parent folder,
-- otherwise its fixed list (empty for most libraries)
fn PHB_libCategories = (
    if PHB_kh.categoryParentOf PHB_library != undefined and PHB_catLists[PHB_library] != undefined \
        then PHB_catLists[PHB_library] else PHB_kh.categoriesOf PHB_library
)

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
    local thumbW = 307
    local thumbH = 173
    local thumbs = #() -- Bitmaps of the library on screen, same order as PHB_items
    local shown = #() -- PHB_items indices of the gallery entries (the selected category)

    -- Library tabs; one per entry in PHB_kh.libraries, same order
    checkbutton tabLib1 "BACKPLATES" pos:[20,6] width:120 height:31
    checkbutton tabLib2 "DECALS" pos:[142,6] width:120 height:31
    checkbutton tabLib3 "GRASS" pos:[264,6] width:120 height:31
    checkbutton tabLib4 "BUILDINGS & PARTS" pos:[386,6] width:160 height:31
    checkbutton tabLib5 "TEXTURES" pos:[548,6] width:120 height:31
    -- Category list, only for libraries that define categories
    label lblCategory "Category:" pos:[700,14] visible:false
    dropdownlist ddlCategory "" pos:[756,10] width:220 visible:false
    -- Positions below are for the full 1296x996 size; layout moves them for smaller screens
    groupBox grpLib "Knowledge Hub Library" pos:[10,42] width:1276 height:890
    dotNetControl lvBackgrounds "System.Windows.Forms.ListView" pos:[20,60] width:1256 height:862
    label lblStatus "" pos:[20,936] width:240
    button btnRefresh "Refresh" pos:[20,953] width:96 height:31
    button btnImport "IMPORT SELECTED" width:240 height:48 pos:[528,941]
    button btnLogout "Sign out" pos:[1180,953] width:96 height:31

    -- Fits the controls to the dialog size picked by PHB_dialogSize. Fewer rows show on a lower
    -- screen; on a narrower one the thumbnails shrink so a row still holds three.
    fn layout w h = (
        local listW = w - 40
        local listH = h - 134
        grpLib.width = w - 20
        grpLib.height = listH + 28
        lvBackgrounds.width = listW
        lvBackgrounds.height = listH
        local y = listH + 74
        lblStatus.pos = [20, y]
        btnRefresh.pos = [20, y + 17]
        btnImport.pos = [(w - 240) / 2, y + 5]
        btnLogout.pos = [w - 116, y + 17]
        local scrollW = (dotNetClass "System.Windows.Forms.SystemInformation").VerticalScrollBarWidth
        thumbW = amin 307 ((listW - 6 - scrollW) / 3 - 40)
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

    fn updateCategories = (
        local cats = PHB_libCategories()
        local has = cats.count > 0
        lblCategory.visible = has
        ddlCategory.visible = has
        if has do (
            local names = #("All")
            for c in cats do append names c[1]
            ddlCategory.items = names
            local sel = PHB_category[PHB_library]
            ddlCategory.selection = if sel != undefined and sel <= names.count then sel else 1
        )
    )

    -- Fills the list with the thumbnails of the selected category (all of them without a list)
    fn showItems = (
        local cat = if ddlCategory.visible then ddlCategory.selection - 1 else 0
        shown = #()
        for i = 1 to thumbs.count do
            if cat == 0 or PHB_items[i][4] == cat do append shown i
        lvBackgrounds.Items.Clear()
        -- The ImageList only gives every cell its height; drawItem paints the thumbnails
        local imgList = dotNetObject "System.Windows.Forms.ImageList"
        imgList.ImageSize = dotNetObject "System.Drawing.Size" 256 thumbH
        lvBackgrounds.LargeImageList = imgList
        setIconSpacing()
        lvBackgrounds.BeginUpdate()
        for i in shown do (
            local lvi = dotNetObject "System.Windows.Forms.ListViewItem" PHB_items[i][1]
            lvi.ImageIndex = 0
            lvBackgrounds.Items.Add lvi
        )
        lvBackgrounds.EndUpdate()
        lblStatus.text = (shown.count as string) + " items"
    )

    fn fillList = (
        lvBackgrounds.Items.Clear()
        updateCategories()
        local onHub = (PHB_kh.foldersOf PHB_library cats:(PHB_libCategories())).count > 0
        btnImport.enabled = onHub
        btnRefresh.enabled = onHub
        if not onHub do (
            thumbs = #()
            shown = #()
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
        local idx = shown[e.ItemIndex + 1]
        local bmp = if idx != undefined then thumbs[idx] else undefined
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

    fn showTab i = (
        tabLib1.checked = (i == 1)
        tabLib2.checked = (i == 2)
        tabLib3.checked = (i == 3)
        tabLib4.checked = (i == 4)
        tabLib5.checked = (i == 5)
    )

    fn switchLibrary i = (
        showTab i -- clicking the active tab keeps it pressed
        if i == PHB_library do return ok
        local prev = PHB_library
        PHB_library = i
        if PHB_loadLibrary() then fillList() else (
            PHB_library = prev
            showTab prev
        )
    )

    fn importSelected = (
        if lvBackgrounds.SelectedItems.Count == 0 do (
            messageBox "Please select an item first." title:"Info"
            return false
        )
        local idx = (lvBackgrounds.SelectedItems.Item[0]).Index + 1
        PHB_importBackground PHB_items[shown[idx]]
    )

    on PHB_mainRollout open do (
        PHB_mainRollout.title = "Physicl Hub Browser v" + PHB_version
        lvBackgrounds.View = (dotNetClass "System.Windows.Forms.View").LargeIcon
        lvBackgrounds.MultiSelect = false
        lvBackgrounds.HideSelection = false
        lvBackgrounds.OwnerDraw = true
        try (layout PHB_mainRollout.width PHB_mainRollout.height) catch (
            format "Physicl Hub Browser: could not fit the dialog to the screen: %\n" (getCurrentException())
        )
        local drawingColor = dotNetClass "System.Drawing.Color"
        lvBackgrounds.BackColor = drawingColor.FromArgb 40 40 40
        lvBackgrounds.ForeColor = drawingColor.FromArgb 220 220 220

        showTab PHB_library
        fillList()
    )

    on tabLib1 changed st do switchLibrary 1
    on tabLib2 changed st do switchLibrary 2
    on tabLib3 changed st do switchLibrary 3
    on tabLib4 changed st do switchLibrary 4
    on tabLib5 changed st do switchLibrary 5
    on ddlCategory selected i do (
        PHB_category[PHB_library] = i
        showItems()
    )
    on btnRefresh pressed do (if PHB_loadLibrary force:true do fillList())
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
