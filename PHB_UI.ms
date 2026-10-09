-- Physicl Hub Browser UI: Knowledge Hub login, gallery and import.
-- Evaluated at global scope by the macroScript (PhysiclHubBrowser.mcr); needs PHB_Client.ms loaded first.

global PHB_kh
global PHB_items = #() -- #(title, previewFileId, packageFileId)
global PHB_loginOk = false
global PHB_library -- index into PHB_kh.libraries; kept between openings
if PHB_library == undefined do PHB_library = 1
global PHB_mainRollout
-- Per library: #(items, ImageList). Filled on first visit, reused on tab switches and reopenings,
-- rebuilt only by Refresh.
global PHB_cache
if PHB_cache == undefined do PHB_cache = #()
global PHB_loginRollout
global PHB_importResult = "" -- one-line outcome of the last import, shown in the dialog

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

fn PHB_importBackground item = (
    local title = item[1]
    PHB_importResult = "Import failed: " + title
    if maxFilePath == "" do (
        PHB_importResult += " (scene not saved)"
        messageBox "Please save the scene first: textures are copied next to the .max file." title:"Scene Not Saved"
        return false
    )

    progressStart ("Downloading " + title + "...")
    local dir = PHB_kh.getPackage title item[3]
    progressEnd()
    if dir == undefined do (
        messageBox ("Could not get " + title + ":\n" + PHB_kh.lastError) title:"Physicl Hub Browser"
        return false
    )

    local maxFiles = PHB_kh.findFiles dir "*.max"
    if maxFiles.count == 0 do (
        messageBox ("The package for " + title + " has no .max file.") title:"Physicl Hub Browser"
        return false
    )
    local maxFile = maxFiles[1]
    for f in maxFiles where matchPattern (getFilenameFile f) pattern:(title + "*") do (maxFile = f; exit)

    -- Merge the object(s) named after the background, or everything if none match
    local names = getMAXFileObjectNames maxFile
    local toMerge = for n in names where matchPattern n pattern:(title + "*") collect n
    if toMerge.count == 0 do toMerge = names

    try (
        mergeMAXFile maxFile toMerge #select #autoRenameDups
    ) catch (
        messageBox ("Error importing " + title + ":\n" +getCurrentException()) title:"Physicl Hub Browser"
        return false
    )
    local objs = selection as array
    if objs.count == 0 do return false

    local tex = PHB_localizeTextures objs dir
    local missing = tex[2]
    if missing.count > 0 do (
        local msg = "Imported " + title + ", but these textures were not found:\n"
        for m in missing do msg += m + "\n"
        messageBox msg title:"Physicl Hub Browser"
    )
    -- Leave the imported object(s) selected so they can be placed right away
    select (for o in objs where isValidNode o collect o)
    completeRedraw()
    format "Physicl Hub Browser: imported % (% objects)\n" title objs.count
    PHB_importResult = "Imported: " + title + " (" + objs.count as string + " objects, " + tex[1] as string + " textures"
    if missing.count > 0 do PHB_importResult += ", " + missing.count as string + " missing"
    PHB_importResult += ")"
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

-- Loads the current library into PHB_items, asking to sign in when the session is missing or expired.
-- Uses the in-memory copy unless force:true (Refresh).
fn PHB_loadLibrary force:false = (
    local cached = PHB_cache[PHB_library]
    if not force and cached != undefined do (
        PHB_items = cached[1]
        return true
    )
    local folderId = PHB_kh.libraries[PHB_library][2]
    if folderId == undefined do (
        -- Section without a Hub folder yet: nothing to fetch
        PHB_items = #()
        PHB_cache[PHB_library] = #(PHB_items, undefined)
        return true
    )
    local r = PHB_kh.fetchCards folderId
    if r[1] == #unauthorized do (
        if not (PHB_ensureLogin()) do return false
        r = PHB_kh.fetchCards folderId
    )
    if r[1] != #ok do (
        messageBox ("Could not load the library:\n" + PHB_kh.lastError) title:"Physicl Hub Browser"
        return false
    )
    PHB_items = r[2]
    PHB_cache[PHB_library] = #(PHB_items, undefined) -- thumbnails are (re)built by fillList
    true
)

-- ============================
-- ROLLOUT: Main UI
-- ============================
rollout PHB_mainRollout "Physicl Hub Browser v1.1" width:680 height:590
(
    -- Library tabs; one per entry in PHB_kh.libraries, same order
    checkbutton tabLib1 "BACKPLATES" pos:[20,6] width:100 height:26
    checkbutton tabLib2 "DECALS" pos:[122,6] width:100 height:26
    checkbutton tabLib3 "GRASS" pos:[224,6] width:100 height:26
    checkbutton tabLib4 "BUILDINGS" pos:[326,6] width:100 height:26
    checkbutton tabLib5 "TEXTURES" pos:[428,6] width:100 height:26
    group "Knowledge Hub Library" (
        dotNetControl lvBackgrounds "System.Windows.Forms.ListView" width:640 height:450 align:#center
    )
    -- Item count, or the result of the last import (wraps to two lines for long titles)
    label lblStatus "" pos:[20,520] width:215 height:30
    button btnRefresh "Refresh" pos:[20,552] width:80 height:26
    button btnImport "IMPORT SELECTED" width:200 height:40 pos:[240,540]
    button btnLogout "Sign out" pos:[580,552] width:80 height:26

    fn makeThumb file = (
        -- Read through a stream so the cached file is not locked while the dialog is open.
        -- Fit inside 160x90 keeping the aspect ratio (decals are mostly square, backgrounds wide).
        local fs = (dotNetClass "System.IO.File").OpenRead file
        local img = (dotNetClass "System.Drawing.Image").FromStream fs
        local bmp = dotNetObject "System.Drawing.Bitmap" 160 90
        local gfx = (dotNetClass "System.Drawing.Graphics").FromImage bmp
        gfx.Clear ((dotNetClass "System.Drawing.Color").FromArgb 40 40 40)
        local s = amin (160.0 / img.Width) (90.0 / img.Height)
        local w = (img.Width * s) as integer
        local h = (img.Height * s) as integer
        gfx.DrawImage img ((160 - w) / 2) ((90 - h) / 2) w h
        gfx.Dispose()
        img.Dispose()
        fs.Close()
        bmp
    )

    fn grayThumb = (
        local bmp = dotNetObject "System.Drawing.Bitmap" 160 90
        local gfx = (dotNetClass "System.Drawing.Graphics").FromImage bmp
        gfx.Clear ((dotNetClass "System.Drawing.Color").Gray)
        gfx.Dispose()
        bmp
    )

    fn fillList = (
        lvBackgrounds.Items.Clear()
        local onHub = PHB_kh.libraries[PHB_library][2] != undefined
        btnImport.enabled = onHub
        btnRefresh.enabled = onHub
        if not onHub do (
            lblStatus.text = "Coming soon"
            return ok
        )
        local cached = PHB_cache[PHB_library]
        if cached != undefined and cached[2] != undefined do (
            -- Already built: just show it
            lvBackgrounds.BeginUpdate()
            lvBackgrounds.LargeImageList = cached[2]
            for i = 1 to PHB_items.count do (
                local lvi = dotNetObject "System.Windows.Forms.ListViewItem" PHB_items[i][1]
                lvi.ImageIndex = i - 1
                lvBackgrounds.Items.Add lvi
            )
            lvBackgrounds.EndUpdate()
            lblStatus.text = (PHB_items.count as string) + " items"
            return ok
        )
        local imgList = dotNetObject "System.Windows.Forms.ImageList"
        imgList.ImageSize = dotNetObject "System.Drawing.Size" 160 90 -- 16:9 thumbnails
        imgList.ColorDepth = (dotNetClass "System.Windows.Forms.ColorDepth").Depth32Bit
        lvBackgrounds.LargeImageList = imgList

        progressStart ("Loading " + PHB_kh.libraries[PHB_library][1] + " from Knowledge Hub...")
        lvBackgrounds.BeginUpdate()
        for i = 1 to PHB_items.count do (
            local item = PHB_items[i]
            local file = PHB_kh.getPreview item[1] item[2]
            local thumb = undefined
            if file != undefined do thumb = try (makeThumb file) catch (undefined)
            imgList.Images.Add (if thumb != undefined then thumb else grayThumb())

            local lvi = dotNetObject "System.Windows.Forms.ListViewItem" item[1]
            lvi.ImageIndex = i - 1
            lvBackgrounds.Items.Add lvi
            if not (progressUpdate (100.0 * i / PHB_items.count)) do exit
        )
        lvBackgrounds.EndUpdate()
        progressEnd()
        -- Keep it only if every thumbnail was added (not cancelled)
        if cached != undefined and imgList.Images.Count == PHB_items.count do cached[2] = imgList
        lblStatus.text = (PHB_items.count as string) + " items"
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
        local result = PHB_importBackground PHB_items[idx]
        lblStatus.text = PHB_importResult
        result
    )

    on PHB_mainRollout open do (
        lvBackgrounds.View = (dotNetClass "System.Windows.Forms.View").LargeIcon
        lvBackgrounds.MultiSelect = false
        lvBackgrounds.HideSelection = false
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
    on btnRefresh pressed do (if PHB_loadLibrary force:true do fillList())
    on btnImport pressed do importSelected()
    on lvBackgrounds DoubleClick s a do importSelected()
    on btnLogout pressed do (
        PHB_kh.logout()
        PHB_items = #()
        PHB_cache = #()
        destroyDialog PHB_mainRollout
    )
)

fn PHB_open = (
    -- A fresh client each time, so a reinstalled PHB_Client.ms takes effect without restarting Max
    PHB_kh = PHB_KHClient()
    PHB_kh.init()
    PHB_kh.loadSession()
    if PHB_library > PHB_kh.libraries.count do PHB_library = 1
    try (destroyDialog PHB_mainRollout) catch ()
    if PHB_loadLibrary() do createDialog PHB_mainRollout
)
