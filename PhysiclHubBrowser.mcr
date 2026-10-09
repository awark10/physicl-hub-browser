macroScript PhysiclHubBrowser
category:"Physicl"
tooltip:"Physicl Hub Browser: backplates and decals from the Knowledge Hub"
buttontext:"Hub Browser"
(
    -- PHB_Client.ms and PHB_UI.ms are installed next to this macro in userMacros
    local dir = (getDir #userMacros) + "\\"
    if not doesFileExist (dir + "PHB_UI.ms") do (
        local here = getSourceFileName()
        if here != undefined do dir = getFilenamePath here
    )
    if doesFileExist (dir + "PHB_Client.ms") and doesFileExist (dir + "PHB_UI.ms") then (
        fileIn (dir + "PHB_Client.ms")
        fileIn (dir + "PHB_UI.ms")
        ::PHB_open()
    ) else (
        messageBox "Physicl Hub Browser files not found.\nReinstall Physicl Hub Browser (Install_PhysiclHubBrowser.ms)." title:"Physicl Hub Browser"
    )
)
