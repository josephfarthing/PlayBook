import 'CoreLibs/graphics'
import "CoreLibs/ui"
import "CoreLibs/crank"
import "CoreLibs/keyboard"

local playdate <const> = playdate
local graphics <const> = playdate.graphics
local min <const> = math.min
local max <const> = math.max
local abs <const> = math.abs
local floor <const> = math.floor
local ceil <const> = math.ceil
local sub <const> = string.sub
local insert <const> = table.insert
local getTextSize <const> = graphics.getTextSize

-- Constants
local DEVICE_WIDTH <const> = 400
local DEVICE_HEIGHT <const> = 240
local VOLUME_ACCELERATION <const> = 0.05
local MAX_VOLUME <const> = 0.025
local CRANK_SCROLL_SPEED <const> = 1.2
local BTN_SCROLL_SPEED <const> = 6
local CHUNK_SIZE <const> = 64 * 1024
local BOOK_SEPARATION <const> = 42

local FONTS <const> = {
    { name = "Roboto Slab", font = graphics.font.new("fonts/roboto-slab-12") },
    { name = "Asheville Ayu", font = graphics.font.new("fonts/asheville/Asheville-Ayu"), height = 20 },
    { name = "Roobert", font = graphics.font.new("fonts/roobert/Roobert-11-Medium") },
    { name = "Monocraft", font = graphics.font.new("fonts/monocraft-18") },
    { name = "Literata Small", font = graphics.font.new("fonts/Literata-Small") },
    { name = "Literata Regular", font = graphics.font.new("fonts/Literata-Regular") },
    { name = "Literata Large", font = graphics.font.new("fonts/Literata-Large") },
}

local LIBRARY = "LIBRARY"
local READER = "READER"

-- Loaded from Save State
local inverted = false
local readerFontId = 1
local crankSpeedModifier = 1
local progressIndicator = 2
local showDefaultBooks = true
local hyphenationEnabled = true
local marginLevel = 1
local lastBookKey = nil
local readingSpeed = 1500 
local tutorialCompleted = false

local booksState = {}
local globalStats = {
    timeReadMs = 0,
    bytesRead = 0,
    finishedBooks = {},
    folders = {}
}
local benchmarkText = nil

local MARGINS_LEFT <const> = {6, 3, 0}
local MARGINS_NO_BORDER <const> = {6, 3, 0}
local MARGINS_WITH_BORDER <const> = {22, 19, 16}

local DEFAULT_BOOKS <const> = {
    "Adventures of Sherlock Holmes.txt",
    "Northanger Abbey.txt",
    "Pride and Prejudice.txt",
    "Frankenstein.txt",
    "The Great Gatsby.txt",
    "Ulysses - James Joyce.pdb",
}

-- Shared State
local scene = LIBRARY
local currentBookKey = nil
local currentBookSettings = nil
local offset = 0
local playScrollSound = true

-- Chunking & File State
local currentFile = nil
local textLength = 0
local textStartOffset = 0
local textChunk = ""
local textChunkStart = 1
local textChunkEnd = 0
local isPDB = false
local currentChapters = {}
local chapterMenuActive = false
local chapterGridView = nil
local currentGlossary = {}

-- Bookmark State
local currentBookmarks = {}
local bookmarkMenuActive = false
local bookmarkGridView = nil
local bPressStartTime = 0
local isHoldingB = false
local bWasHeld = false

-- Navigation State
local navMenuActive = false
local navGridView = nil
local navOptions = {}

-- Layout Geometry
local topLinesHeightOffset = 0

-- Skimming State
local isSkimming = false
local skimProgress = 0

-- Tutorial State
local tutorialActive = false
local tutorialStep = 1

-- Glossary Selection State
local selectableWords = {}
local selectedWordIndex = 1

-- Reading Speed Tracker State
local lastSettleTime = 0
local lastSettleIndex = 1
local lastActivityTime = 0

-- Library/Folder State
local masterLibrary = {}
local availableBooks = {}
local highlightedBook = 1
local currentScrollOffset = 0
local targetScrollOffset = 0
local FOLDER_IN_PROGRESS = -1
local FOLDER_ALL_BOOKS = 0
local currentFolderIndex = 0 
local visualFolderIndex = 0
local isKeyboardOpen = false
local hasScrolledLibrary = false

-- Animation State
local isStartupAnimation = true
local titleAnimationProgress = 0
local fallingBookProgress = 0
local headerYOffset = -40

-- Claw Machine State
local aPressStartTime = 0
local isHoldingA = false
local isMovingBook = false
local floatingBook = nil

-- Library Graphics
local bookImage <const> = graphics.image.new("images/book.png")
local bookmarkImage <const> = graphics.image.new("images/bookmark.png")
local bookmarkBorderImage <const> = graphics.image.new("images/bookmark-border.png")
local titleImage <const> = graphics.image.new("images/title.png")

local tutorialImages = {
    graphics.image.new("images/tutorial-1.png"),
    graphics.image.new("images/tutorial-2.png"),
    graphics.image.new("images/tutorial-3.png"),
    graphics.image.new("images/tutorial-4.png"),
    graphics.image.new("images/tutorial-5.png"),
    graphics.image.new("images/tutorial-6.png")
}

local POSSIBLE_SUBTITLES <const> = {
    {"Made by Idrees"},
    {"A reader lives a thousand", "lives before he dies"},
    {"Books are a uniquely", "portable magic"},
    {"Books are the mirrors", "of the soul."},
    {"There is no friend", "as loyal as a book"},
    {"We read to know", "we're not alone"},
    {"A book is a dream", "that you hold in your hand"},
    {"A book is a device", "to ignite the imagination"},
}
local subtitle = POSSIBLE_SUBTITLES[math.random(#POSSIBLE_SUBTITLES)]

-- Reader Variables
local sound <const> = playdate.sound.synth.new(playdate.sound.kWaveNoise)
local lineHeight = 0
local directionHeld = 0
local leftMargin = 6
local rightMargin = 22
local lines = {}
local emptyLinesAbove = 0
local skipSoundTicks = 0
local skipScrollTicks = 0
local previousCrankOffset = 0
local indexAtTopOfScreen = 1
local textProgress = 0
local menuActive = false
local lastOffset = -1000
local forceRedraw = false

-- UI Graphics
local candleFlameOne = graphics.image.new("images/candle-flame-1.png")
local candleFlameTwo = graphics.image.new("images/candle-flame-2.png")
local candleFlameThree = graphics.image.new("images/candle-flame-3.png")
local candleTop = graphics.image.new("images/candle-top.png")
local candleSection = graphics.image.new("images/candle-section.png")
local candleDripLeft = graphics.image.new("images/candle-drip-left.png")
local candleDripRight = graphics.image.new("images/candle-drip-right.png")
local candleHolder = graphics.image.new("images/candle-holder.png")
local flame = candleFlameOne

local scrollbarArrow = graphics.image.new("images/scrollbar-arrow.png")
local scrollbarButton = graphics.image.new("images/scrollbar-button.png")
local scrollbarSection = graphics.image.new("images/scrollbar-section.png")
local scrollbarSlider = graphics.image.new("images/scrollbar-slider.png")

-- Forward Declarations
local loadBook, loadTextChunk, reloadReader, appendLines, prependLines, addLines, removeLines
local buildMenuOptions, initMenu, initializeLines, initChapterMenu, initBookmarkMenu, setupSystemMenu, initLibrary
local openNavMenu, drawNavMenu, updateTargetScroll, drawTutorialOverlay
local scanLibrary, updateFolderView, loadCurrentBookSettings
local drawSkimOverlay, drawBenchmarkOverlay, runBenchmark, registerActivity
local saveState
local MENU_OPTIONS = {}

local function easeOut(t) 
    t = math.max(0, math.min(1, t))
    return 1 - (1 - t) * (1 - t) 
end

-----------------------------------------
-- CORE LOGIC
-----------------------------------------

registerActivity = function()
    lastActivityTime = playdate.getCurrentTimeMilliseconds()
    playdate.display.setRefreshRate(50)
end

local function setInverted(darkMode)
    inverted = darkMode
    playdate.display.setInverted(inverted)
end

local function updateMargins()
    leftMargin = MARGINS_LEFT[marginLevel]
    if progressIndicator == 1 then rightMargin = MARGINS_NO_BORDER[marginLevel]
    else rightMargin = MARGINS_WITH_BORDER[marginLevel] end
end

local function setMarginLevel(level)
    marginLevel = level
    updateMargins()
    reloadReader()
end

local function setHyphenation(enabled)
    hyphenationEnabled = enabled
    reloadReader() 
end

local function setProgressIndicator(indicator)
    progressIndicator = indicator
    updateMargins()
    reloadReader()
end

runBenchmark = function()
    registerActivity()
    local stats = {}
    local t1 = playdate.getCurrentTimeMilliseconds()
    local currentIdx = indexAtTopOfScreen
    local nextChunkIdx = currentIdx + CHUNK_SIZE
    if nextChunkIdx > textLength then nextChunkIdx = 1 end
    loadTextChunk(nextChunkIdx)
    local t2 = playdate.getCurrentTimeMilliseconds()
    insert(stats, "64KB Disk Load: " .. (t2 - t1) .. "ms")
    
    loadTextChunk(currentIdx)
    local memStart = collectgarbage("count")
    local t3 = playdate.getCurrentTimeMilliseconds()
    local backupLines, backupEmpty, backupHeight = lines, emptyLinesAbove, topLinesHeightOffset
    lines, emptyLinesAbove, topLinesHeightOffset = {}, 0, 0
    
    addLines(200, true, currentIdx)
    local t4 = playdate.getCurrentTimeMilliseconds()
    local memEnd = collectgarbage("count")
    
    insert(stats, "Layout 200 lines: " .. (t4 - t3) .. "ms")
    insert(stats, "Memory Delta: " .. math.floor(memEnd - memStart) .. " KB")
    lines, emptyLinesAbove, topLinesHeightOffset = backupLines, backupEmpty, backupHeight
    forceRedraw = true
    benchmarkText = table.concat(stats, "\n")
end

local function getOrDefault(t, key, expectedType, default)
    local value = t[key]
    if value == nil then return default
    else
        if type(value) ~= expectedType then return default end
        return value
    end
end

saveState = function()
    local state = {}
    state.inverted = inverted
    if currentBookKey ~= nil and currentBookSettings ~= nil then
        currentBookSettings.readIndex = indexAtTopOfScreen
        currentBookSettings.progress = textProgress
        currentBookSettings.bookmarks = currentBookmarks
        booksState[currentBookKey] = currentBookSettings
    end
    state.books = booksState
    state.font = readerFontId
    state.crankSpeedModifier = crankSpeedModifier
    state.progressIndicator = progressIndicator
    state.playScrollSound = playScrollSound
    state.showDefaultBooks = showDefaultBooks
    state.hyphenationEnabled = hyphenationEnabled
    state.marginLevel = marginLevel
    state.lastBookKey = currentBookKey
    state.readingSpeed = readingSpeed
    state.tutorialCompleted = tutorialCompleted
    state.globalStats = globalStats
    playdate.datastore.write(state)
end

local function loadState()
    local state = playdate.datastore.read() or {}
    setInverted(getOrDefault(state, "inverted", "boolean", inverted))
    booksState = getOrDefault(state, "books", "table", {})
    readerFontId = getOrDefault(state, "font", "number", readerFontId)
    crankSpeedModifier = getOrDefault(state, "crankSpeedModifier", "number", crankSpeedModifier)
    progressIndicator = getOrDefault(state, "progressIndicator", "number", progressIndicator)
    playScrollSound = getOrDefault(state, "playScrollSound", "boolean", playScrollSound)
    showDefaultBooks = getOrDefault(state, "showDefaultBooks", "boolean", showDefaultBooks)
    hyphenationEnabled = getOrDefault(state, "hyphenationEnabled", "boolean", true)
    marginLevel = getOrDefault(state, "marginLevel", "number", 1)
    lastBookKey = getOrDefault(state, "lastBookKey", "string", nil)
    readingSpeed = getOrDefault(state, "readingSpeed", "number", 1500)
    tutorialCompleted = getOrDefault(state, "tutorialCompleted", "boolean", false)
    
    local loadedStats = getOrDefault(state, "globalStats", "table", {})
    globalStats.timeReadMs = getOrDefault(loadedStats, "timeReadMs", "number", 0)
    globalStats.bytesRead = getOrDefault(loadedStats, "bytesRead", "number", 0)
    globalStats.finishedBooks = getOrDefault(loadedStats, "finishedBooks", "table", {})
    globalStats.folders = getOrDefault(loadedStats, "folders", "table", {})
    
    if globalStats.bytesRead > 20000 and globalStats.timeReadMs < 60000 then
        globalStats.timeReadMs = 0
        globalStats.bytesRead = 0
    end
    
    updateMargins()
end

loadCurrentBookSettings = function()
    currentBookSettings = booksState[currentBookKey] or {}
    currentBookSettings.readIndex = getOrDefault(currentBookSettings, "readIndex", "number", 1)
    currentBookSettings.progress = getOrDefault(currentBookSettings, "progress", "number", 0)
    currentBookmarks = getOrDefault(currentBookSettings, "bookmarks", "table", {})
end

-----------------------------------------
-- LIBRARY / FOLDER LOGIC
-----------------------------------------

scanLibrary = function()
    local tempBooks = {}
    local folders = {""}
    
    local files = playdate.file.listFiles("books")
    if files then
        for i = 1, #files do
            if playdate.file.isdir("books/" .. files[i]) then insert(folders, files[i]) end
        end
    end
    
    local defaultBooksSet = {}
    if not showDefaultBooks then
        for j = 1, #DEFAULT_BOOKS do defaultBooksSet[DEFAULT_BOOKS[j]] = true end
    end

    for f = 1, #folders do
        local folderPath = folders[f]
        local folderFiles = playdate.file.listFiles("books/" .. folderPath)
        
        if folderFiles then
            for i = 1, #folderFiles do
                local file = folderFiles[i]
                local ext = string.lower(sub(file, -4))
                
                if not defaultBooksSet[file] and (ext == ".txt" or ext == ".pdb") then
                    local path = folderPath .. file
                    local name = sub(file, 1, -5)
                    insert(tempBooks, { path = path, name = name })
                end
            end
        end
    end
    
    -- Case-insensitive true A-Z sorting
    table.sort(tempBooks, function (a, b) return string.lower(a.name) < string.lower(b.name) end)
    masterLibrary = tempBooks
end

local function getFolderName(index)
    if index == FOLDER_IN_PROGRESS then return "In Progress" end
    if index == FOLDER_ALL_BOOKS then return "All Books" end
    if index > 0 and index <= #globalStats.folders then return globalStats.folders[index].name end
    if index == #globalStats.folders + 1 then return "New Folder" end
    return nil
end

updateTargetScroll = function()
    if highlightedBook <= 1 then
        targetScrollOffset = 0
    else
        local titleBottom = (currentFolderIndex == FOLDER_ALL_BOOKS) and (36 + 125) or (36 + 20)
        local bookY = titleBottom + ((highlightedBook - 1) * BOOK_SEPARATION)
        targetScrollOffset = math.max(0, bookY - 110)
    end
end

updateFolderView = function(skipDropAnimation)
    availableBooks = {}
    
    if currentFolderIndex == FOLDER_ALL_BOOKS then
        for i = 1, #masterLibrary do insert(availableBooks, masterLibrary[i]) end
    elseif currentFolderIndex == FOLDER_IN_PROGRESS then
        for i = 1, #masterLibrary do
            local book = masterLibrary[i]
            local isFinished = globalStats.finishedBooks[book.name]
            local hasProgress = booksState[book.name] and booksState[book.name].progress > 0.001
            if hasProgress and not isFinished then insert(availableBooks, book) end
        end
    elseif currentFolderIndex > 0 and currentFolderIndex <= #globalStats.folders then
        local folder = globalStats.folders[currentFolderIndex]
        local folderBooksMap = {}
        if folder.books then
            for j = 1, #folder.books do folderBooksMap[folder.books[j]] = true end
        end
        for i = 1, #masterLibrary do
            if folderBooksMap[masterLibrary[i].name] then insert(availableBooks, masterLibrary[i]) end
        end
    end
    
    highlightedBook = (#availableBooks > 0) and 1 or 0
    updateTargetScroll()
    currentScrollOffset = targetScrollOffset
    
    if skipDropAnimation then
        fallingBookProgress = 20000 
        titleAnimationProgress = 1
        headerYOffset = 0
    else
        if isStartupAnimation then
            fallingBookProgress = -1600
            titleAnimationProgress = -0.6
            headerYOffset = -40
            isStartupAnimation = false
        else
            fallingBookProgress = -500
            titleAnimationProgress = 0
            headerYOffset = 0
        end
    end
    
    setupSystemMenu()
end

local function promptNewFolder()
    if #globalStats.folders >= 5 then return end
    
    isKeyboardOpen = true
    playdate.keyboard.keyboardWillHideCallback = function(pressedOK)
        isKeyboardOpen = false
        if pressedOK then
            local text = playdate.keyboard.text
            if text and text ~= "" and text:match("%S") then
                insert(globalStats.folders, { name = text, books = {} })
                saveState()
                currentFolderIndex = #globalStats.folders
            else
                currentFolderIndex = math.max(FOLDER_IN_PROGRESS, currentFolderIndex - 1)
            end
        else
            currentFolderIndex = math.max(FOLDER_IN_PROGRESS, currentFolderIndex - 1)
        end
        updateFolderView(false)
        forceRedraw = true
    end
    
    playdate.keyboard.show("")
end

initLibrary = function(skipDropAnimation)
    registerActivity()
    scanLibrary()
    
    scene = LIBRARY
    offset = 0
    lastOffset = -1000
    directionHeld = 0
    sound:setVolume(0)
    hasScrolledLibrary = false
    
    updateFolderView(skipDropAnimation)
    forceRedraw = true
end

-----------------------------------------
-- TEXT PARSING & BOOK LOADING
-----------------------------------------

loadBook = function(selectedBook)
    if currentFile then currentFile:close() end
    currentBookKey = selectedBook.name
    loadCurrentBookSettings()
    
    local ext = string.lower(sub(selectedBook.path, -4))
    isPDB = (ext == ".pdb")
    currentChapters = {}
    currentGlossary = {}
    
    currentFile = playdate.file.open("books/" .. selectedBook.path)
    if currentFile == nil then return end
    
    if isPDB then
        local headerChunkSize = 128 * 1024
        local headerBuffer = ""
        local separatorIndex = nil
        
        while true do
            local chunk = currentFile:read(headerChunkSize)
            if not chunk then break end
            headerBuffer = headerBuffer .. chunk
            separatorIndex = string.find(headerBuffer, "\n%-%-%-PDB%-%-%-\n")
            if separatorIndex then break end
            if #headerBuffer > 1024 * 1024 then break end
        end
        
        if separatorIndex then
            local jsonString = string.sub(headerBuffer, 1, separatorIndex - 1)
            local metadata = json.decode(jsonString)
            if metadata and metadata.chapters then
                currentChapters = metadata.chapters
                initChapterMenu()
            end
            if metadata and metadata.glossary then currentGlossary = metadata.glossary end
            textStartOffset = separatorIndex + 11 - 1
        else
            textStartOffset = 0
        end
    else
        textStartOffset = 0
    end
    
    currentFile:seek(0, playdate.file.kSeekFromEnd)
    textLength = currentFile:tell() - textStartOffset
    textChunkStart = 1
    textChunkEnd = 0 
    
    initMenu()
    reloadReader()
    
    if not tutorialCompleted then
        tutorialActive = true
        tutorialStep = 1
        forceRedraw = true
    end
end

loadTextChunk = function(targetIndex)
    if not currentFile then return end
    local halfChunk = math.floor(CHUNK_SIZE / 2)
    local startIdx = targetIndex - halfChunk
    
    if startIdx < 1 then startIdx = 1 end
    if startIdx + CHUNK_SIZE - 1 > textLength then startIdx = math.max(1, textLength - CHUNK_SIZE + 1) end
    
    currentFile:seek(textStartOffset + startIdx - 1)
    textChunk = currentFile:read(CHUNK_SIZE)
    if not textChunk then textChunk = "" end
    
    textChunkStart = startIdx
    textChunkEnd = startIdx + #textChunk - 1
end

reloadReader = function()
    saveState()
    scene = READER
    setupSystemMenu()
    offset = 0
    lastOffset = -1000
    directionHeld = 0
    topLinesHeightOffset = 0
    lines = {}
    skipSoundTicks = 0
    skipScrollTicks = 0
    previousCrankOffset = 0
    textProgress = 0
    wasMoving = true
    
    lastSettleIndex = currentBookSettings.readIndex or 1
    lastSettleTime = playdate.getCurrentTimeMilliseconds()

    sound:setVolume(0)
    sound:playNote(850)
    
    graphics.setFont(FONTS[readerFontId].font)
    if FONTS[readerFontId].height ~= nil then lineHeight = FONTS[readerFontId].height
    else lineHeight = graphics.getTextSize("A") * 1.6 end

    if currentBookSettings ~= nil then
        initializeLines(currentBookSettings.readIndex)
    end
end

removeLines = function(numOfLines, fromBottom)
    if numOfLines == 0 then return end
    if fromBottom then
        for i = 1, numOfLines do table.remove(lines) end
    else
        for i = 1, numOfLines do 
            topLinesHeightOffset = topLinesHeightOffset + lines[1].height
            table.remove(lines, 1) 
        end
    end
end

prependLines = function(linesNeeded, startChar)
    local initialCount = #lines
    addLines(linesNeeded, false, startChar)
    local numAdded = #lines - initialCount
    local addedHeight = 0
    for i = 1, numAdded do addedHeight = addedHeight + lines[i].height end
    topLinesHeightOffset = topLinesHeightOffset - addedHeight
    return numAdded
end

appendLines = function(linesNeeded, startChar)
    local initialCount = #lines
    addLines(linesNeeded, true, startChar)
    return #lines - initialCount
end

initializeLines = function(startChar)
    local numAdded = appendLines(20, startChar)
    prependLines(20 - numAdded)
    topLinesHeightOffset = 0
end

addLines = function(additionalLines, append, startChar)
    playdate.resetElapsedTime()
    if not currentFile then return 0 end
    
    graphics.setFont(FONTS[readerFontId].font)
    local initialNumOfLines <const> = #lines
    local numOfLines = initialNumOfLines
    local byteIndex = 1
    
    if startChar then byteIndex = startChar
    elseif numOfLines > 0 then
        if append then byteIndex = lines[#lines].stop + 1
        else byteIndex = lines[1].start - 1 end
    end
    
    if byteIndex < 1 or byteIndex > textLength then return 0 end
    
    local getChunkByte = function(index)
        if index < textChunkStart or index > textChunkEnd then loadTextChunk(index) end
        return string.byte(textChunk, index - textChunkStart + 1)
    end
    
    local isStartOfChar = function(byte) return byte < 128 or byte >= 192 end
    local isContinuationByte = function(byte) return byte >= 128 and byte < 192 end
    local getCharLength = function(byte)
        if byte < 192 then return 1
        elseif byte < 224 then return 2
        elseif byte < 240 then return 3
        elseif byte < 248 then return 4
        else return 1 end
    end
    
    local findStartOfChar = function(index, direction)
        local i = index
        while i > 1 and i <= textLength and not isStartOfChar(getChunkByte(i)) do i = i + direction end
        if i > 0 and i <= textLength and isStartOfChar(getChunkByte(i)) then return i else return nil end
    end
    
    local isCompleteChar = function(char)
        local firstByte = char:byte(1)
        if not isStartOfChar(firstByte) then return false end
        local charLength = getCharLength(firstByte)
        if #char ~= charLength then return false end
        for i = 2, charLength do
            if not isContinuationByte(char:byte(i)) then return false end
        end
        return true
    end
    
    if append then
        if not isStartOfChar(getChunkByte(byteIndex)) then
            local result = findStartOfChar(byteIndex, 1)
            if result then byteIndex = result else return 0 end
        end
    else
        local isEndOfChar = function(idx)
            local startIdx = findStartOfChar(idx, -1)
            if not startIdx then return false end
            local firstByte = getChunkByte(startIdx)
            return (startIdx + getCharLength(firstByte) - 1) == idx
        end
        if not isEndOfChar(byteIndex) then
            local result = findStartOfChar(byteIndex, -1)
            if result then byteIndex = result + getCharLength(getChunkByte(result)) - 1 else return 0 end
        end
    end
    
    local MAX_WIDTH <const> = DEVICE_WIDTH - leftMargin - rightMargin
    local currentLine = ""
    local currentLineWidth = 0
    local lineStart = byteIndex
    local lineStop = byteIndex
    local lastSpace, lastSpaceIndex, lastHyphen, lastHyphenIndex, lastHyphenIsSoft = nil, nil, nil, nil, false
    
    local insertLine = function (line, start, stop, nextLine)
        if nextLine == nil then nextLine = "" end
        
        local h = lineHeight
        local gWords = {}
        local cx = leftMargin
        
        for fullWord, space in string.gmatch(line, "(%S+)(%s*)") do
            local cw = string.match(string.lower(fullWord), "[a-z]+")
            if cw and currentGlossary[cw] then
                local wWidth = getTextSize(fullWord)
                insert(gWords, { fullWord=fullWord, cleanWord=cw, def=currentGlossary[cw], x=cx, w=wWidth })
            end
            cx = cx + getTextSize(fullWord .. space)
        end
        
        local lineObj = { text = line, start = start, stop = stop, height = h, glossaryWords = gWords }
        if append then insert(lines, lineObj)
        else insert(lines, 1, lineObj) end
        
        currentLine = nextLine
        currentLineWidth = getTextSize(nextLine)
        numOfLines = numOfLines + 1
        
        lastSpace, lastSpaceIndex, lastHyphen, lastHyphenIndex, lastHyphenIsSoft = nil, nil, nil, nil, false
        
        if append then
            lineStart = stop + 1
            lineStop = lineStart + #nextLine
        else
            lineStop = start - 1
            lineStart = lineStop - #nextLine
        end

        if currentLine ~= "" then
            if append then
                for i = #currentLine, 1, -1 do
                    local c = sub(currentLine, i, i)
                    if c == " " and not lastSpace then
                        lastSpace, lastSpaceIndex = i, lineStart + i - 1
                    elseif c == "-" and not lastHyphen then
                        lastHyphen, lastHyphenIndex = i, lineStart + i - 1
                        lastHyphenIsSoft = false
                    end
                    if lastSpace and lastHyphen then break end
                end
            else
                for i = 1, #currentLine do
                    local c = sub(currentLine, i, i)
                    if c == " " and not lastSpace then
                        lastSpace, lastSpaceIndex = #currentLine - i + 1, lineStop - (#currentLine - i)
                    elseif c == "-" and not lastHyphen then
                        lastHyphen, lastHyphenIndex = #currentLine - i + 1, lineStop - (#currentLine - i)
                        lastHyphenIsSoft = false
                    end
                    if lastSpace and lastHyphen then break end
                end
            end
        end
    end
    
    local char = ""
    while numOfLines < initialNumOfLines + additionalLines do
        if byteIndex < 1 or byteIndex > textLength then
            if currentLine ~= "" then insertLine(currentLine, lineStart, lineStop) end
            break
        end
        
        if byteIndex < textChunkStart or byteIndex > textChunkEnd then loadTextChunk(byteIndex) end
        local localIdx = byteIndex - textChunkStart + 1
        local byteVal = string.byte(textChunk, localIdx)
        
        if byteVal ~= 13 then
            local chunk = string.char(byteVal)
            if append then char = char .. chunk else char = chunk .. char end
            
            if isCompleteChar(char) then
                if char == "\194\173" then
                    if hyphenationEnabled then
                        if append then
                            if getTextSize(currentLine .. "-") <= MAX_WIDTH then
                                lastHyphen, lastHyphenIndex = #currentLine, byteIndex
                                lastHyphenIsSoft = true
                            end
                        else
                            lastHyphen, lastHyphenIndex = #currentLine, byteIndex
                            lastHyphenIsSoft = true
                        end
                    end
                    char = ""
                else
                    local charWidth = getTextSize(char)
                    local isOverWidth = false
                    local combined = nil
                    
                    if currentLineWidth + charWidth > MAX_WIDTH then
                        combined = append and (currentLine .. char) or (char .. currentLine)
                        local exactWidth = getTextSize(combined)
                        if exactWidth > MAX_WIDTH then isOverWidth = true else currentLineWidth = exactWidth end
                    else
                        currentLineWidth = currentLineWidth + charWidth
                    end
                    
                    if char == "\n" then
                        if append then lineStop = byteIndex else lineStart = byteIndex end
                        insertLine(currentLine .. " ", lineStart, lineStop)
                    elseif isOverWidth then
                        if lastHyphen and (not lastSpace or lastHyphen > lastSpace) then
                            local dash = lastHyphenIsSoft and "-" or ""
                            if append then
                                insertLine(sub(currentLine, 1, lastHyphen) .. dash, lineStart, lastHyphenIndex, sub(currentLine, lastHyphen + 1) .. char)
                            else
                                local invH = lastHyphen
                                insertLine(sub(currentLine, #currentLine - invH + 1), lastHyphenIndex + 2, lineStop, char .. sub(currentLine, 1, #currentLine - invH) .. dash)
                            end
                        elseif lastSpace then
                            if append then
                                insertLine(sub(currentLine, 1, lastSpace), lineStart, lastSpaceIndex, sub(currentLine, lastSpace + 1) .. char)
                            else
                                local invS = #currentLine - lastSpace + 1
                                insertLine(sub(currentLine, invS + 1), lineStart + invS, lineStop, char .. sub(currentLine, 1, invS))
                            end
                        else
                            insertLine(currentLine, lineStart, lineStop, char)
                        end
                    else
                        if not combined then combined = append and (currentLine .. char) or (char .. currentLine) end
                        currentLine = combined
                        if char == " " then
                            lastSpace, lastSpaceIndex = #currentLine, byteIndex
                            currentLineWidth = getTextSize(currentLine)
                        elseif char == "-" then
                            lastHyphen, lastHyphenIndex = #currentLine, byteIndex
                            lastHyphenIsSoft = false
                        end
                        if append then lineStop = byteIndex else lineStart = byteIndex end
                    end
                end
                char = ""
            end
        end
        if append then byteIndex = byteIndex + 1 else byteIndex = byteIndex - 1 end
    end
    return numOfLines - initialNumOfLines
end

function toggleBookmark()
    if scene ~= READER then return end
    if not currentBookmarks then currentBookmarks = {} end
    
    local pageStart = indexAtTopOfScreen
    local pageEnd = (#lines > 0) and lines[#lines].stop or textLength
    
    local foundIndex = nil
    for i = 1, #currentBookmarks do
        if currentBookmarks[i].index >= pageStart and currentBookmarks[i].index <= pageEnd then
            foundIndex = i
            break
        end
    end
    
    if foundIndex then
        table.remove(currentBookmarks, foundIndex)
    else
        local t = playdate.getTime()
        local timeStr = string.format("%04d-%02d-%02d %02d:%02d", t.year, t.month, t.day, t.hour, t.minute)
        insert(currentBookmarks, { index = pageStart, time = timeStr })
    end
    
    saveState()
    forceRedraw = true
end

-----------------------------------------
-- UI DRAWING & MENUS
-----------------------------------------

local optionViews = {}
local activeSetting = 1
local OPTIONS_WIDTH <const> = 150

buildMenuOptions = function()
    MENU_OPTIONS = {
        {
            label = "Theme",
            options = { "Light Mode", "Dark Mode" },
            initialValue = function () if inverted then return 2 else return 1 end end,
            callback = function (index) if index == 1 then setInverted(false) else setInverted(true) end end
        },
        {
            label = "Reader Font",
            options = {},
            initialValue = function () return readerFontId end,
            callback = function (index) readerFontId = index reloadReader() end
        },
        {
            label = "Crank Speed",
            options = { "Slower", "Default", "Faster" },
            initialValue = function ()
                if crankSpeedModifier == 0.75 then return 1
                elseif crankSpeedModifier == 1 then return 2
                elseif crankSpeedModifier == 1.25 then return 3
                else return 2 end
            end,
            callback = function (index)
                if index == 1 then crankSpeedModifier = 0.75
                elseif index == 2 then crankSpeedModifier = 1
                elseif index == 3 then crankSpeedModifier = 1.5 end
            end
        },
        {
            label = "Progress Bar",
            options = { "None", "Candle", "Scrollbar" },
            initialValue = function () return progressIndicator end,
            callback = function (index) setProgressIndicator(index) end
        },
        {
            label = "Scroll Sound",
            options = { "Enabled", "Disabled" },
            initialValue = function () if playScrollSound then return 1 else return 2 end end,
            callback = function (index)
                if index == 1 then playScrollSound = true
                elseif index == 2 then playScrollSound = false end
            end
        },
        {
            label = "Included Books",
            options = { "Shown", "Hidden" },
            initialValue = function () if showDefaultBooks then return 1 else return 2 end end,
            callback = function (index)
                if index == 1 then showDefaultBooks = true
                elseif index == 2 then showDefaultBooks = false end
                scanLibrary()
                if scene == LIBRARY then
                    updateFolderView(true)
                    forceRedraw = true
                end
            end
        },
        {
            label = "Margins",
            options = { "Default", "Small", "None" },
            initialValue = function () return marginLevel end,
            callback = function (index) setMarginLevel(index) end
        },
        {
            label = "Tutorial",
            options = { "Ready", "Show ->" },
            initialValue = function () return 1 end,
            callback = function (index)
                if index == 2 then
                    optionViews[activeSetting]:selectPreviousColumn(false)
                    menuActive = false
                    tutorialActive = true
                    tutorialStep = 1
                    forceRedraw = true
                end
            end
        }
    }

    if isPDB then
        insert(MENU_OPTIONS, 6, {
            label = "Hyphenation",
            options = { "Disabled", "Enabled" },
            initialValue = function () if hyphenationEnabled then return 2 else return 1 end end,
            callback = function (index)
                if index == 1 then setHyphenation(false) else setHyphenation(true) end
            end
        })
    end
    
    for i = 1, #FONTS do insert(MENU_OPTIONS[2].options, FONTS[i].name) end
end

initMenu = function()
    buildMenuOptions()
    optionViews = {}
    for i = 1, #MENU_OPTIONS do
        local options = MENU_OPTIONS[i].options
        local gridview = playdate.ui.gridview.new(OPTIONS_WIDTH, 28)
        gridview:setNumberOfRows(1)
        gridview:setNumberOfColumns(#options)
        local initialValue = MENU_OPTIONS[i].initialValue()
        for j = 1, initialValue - 1 do gridview:selectNextColumn(false, true, false) end
        function gridview:drawCell(section, row, column, selected, x, y, width, height)
            if selected then
                if activeSetting == i then
                    graphics.fillRoundRect(x, y, width, height, 4)
                    graphics.setImageDrawMode(graphics.kDrawModeFillWhite)
                else
                    graphics.drawRoundRect(x, y, width, height, 4)
                end
            end
            local fontHeight = graphics.getSystemFont():getHeight()
            graphics.setFont(graphics.getSystemFont())
            graphics.drawTextInRect(options[column], x, y + (height / 2 - fontHeight / 2) + 2, width, height, nil, nil, kTextAlignment.center)
            graphics.setImageDrawMode(graphics.kDrawModeCopy)
        end
        optionViews[i] = gridview
    end
end

initChapterMenu = function()
    chapterGridView = playdate.ui.gridview.new(240, 32)
    chapterGridView:setNumberOfRows(#currentChapters)
    chapterGridView:setNumberOfColumns(1)
    function chapterGridView:drawCell(section, row, column, selected, x, y, width, height)
        if selected then
            graphics.fillRoundRect(x, y, width, height, 4)
            graphics.setImageDrawMode(graphics.kDrawModeFillWhite)
        else
            graphics.drawRoundRect(x, y, width, height, 4)
        end
        local fontHeight = graphics.getSystemFont():getHeight()
        graphics.setFont(graphics.getSystemFont())
        graphics.drawTextInRect(currentChapters[row].title, x + 10, y + (height / 2 - fontHeight / 2) + 2, width - 20, height, nil, "...", kTextAlignment.left)
        graphics.setImageDrawMode(graphics.kDrawModeCopy)
    end
end

initBookmarkMenu = function()
    bookmarkGridView = playdate.ui.gridview.new(240, 32)
    if #currentBookmarks == 0 then
        bookmarkGridView:setNumberOfRows(1)
    else
        bookmarkGridView:setNumberOfRows(#currentBookmarks)
    end
    bookmarkGridView:setNumberOfColumns(1)
    
    function bookmarkGridView:drawCell(section, row, column, selected, x, y, width, height)
        if selected then
            graphics.fillRoundRect(x, y, width, height, 4)
            graphics.setImageDrawMode(graphics.kDrawModeFillWhite)
        else
            graphics.drawRoundRect(x, y, width, height, 4)
        end
        
        local fontHeight = graphics.getSystemFont():getHeight()
        graphics.setFont(graphics.getSystemFont())
        
        local text = "No Bookmarks Yet"
        if #currentBookmarks > 0 then
            local bm = currentBookmarks[row]
            local pct = math.floor((bm.index / textLength) * 100) .. "%"
            text = pct .. " - " .. bm.time
        end
        
        graphics.drawTextInRect(text, x + 10, y + (height / 2 - fontHeight / 2) + 2, width - 20, height, nil, "...", kTextAlignment.left)
        graphics.setImageDrawMode(graphics.kDrawModeCopy)
    end
end

openNavMenu = function()
    navOptions = {}
    if isPDB and #currentChapters > 0 then
        table.insert(navOptions, { label = "Chapters", action = "chapters" })
    end
    table.insert(navOptions, { label = "Bookmarks", action = "bookmarks" })
    
    navGridView = playdate.ui.gridview.new(200, 32)
    navGridView:setNumberOfRows(#navOptions)
    navGridView:setNumberOfColumns(1)
    
    function navGridView:drawCell(section, row, column, selected, x, y, width, height)
        if selected then
            graphics.fillRoundRect(x, y, width, height, 4)
            graphics.setImageDrawMode(graphics.kDrawModeFillWhite)
        else
            graphics.drawRoundRect(x, y, width, height, 4)
        end
        local text = navOptions[row].label
        local fontHeight = graphics.getSystemFont():getHeight()
        graphics.setFont(graphics.getSystemFont())
        graphics.drawTextInRect(text, x + 10, y + (height / 2 - fontHeight / 2) + 2, width - 20, height, nil, "...", kTextAlignment.left)
        graphics.setImageDrawMode(graphics.kDrawModeCopy)
    end
    
    navMenuActive = true
    forceRedraw = true
end

setupSystemMenu = function()
    local systemMenu = playdate.getSystemMenu()
    systemMenu:removeAllMenuItems()
    if scene == LIBRARY then
        if currentFolderIndex > 0 and currentFolderIndex <= #globalStats.folders then
            if highlightedBook > 0 and availableBooks[highlightedBook] then
                systemMenu:addMenuItem("Remove Book", function()
                    local bookName = availableBooks[highlightedBook].name
                    local folderBooks = globalStats.folders[currentFolderIndex].books
                    for i = 1, #folderBooks do
                        if folderBooks[i] == bookName then
                            table.remove(folderBooks, i)
                            break
                        end
                    end
                    saveState()
                    updateFolderView(true)
                    forceRedraw = true
                end)
            end
            systemMenu:addMenuItem("Delete Folder", function()
                table.remove(globalStats.folders, currentFolderIndex)
                saveState()
                currentFolderIndex = FOLDER_ALL_BOOKS
                updateFolderView(true)
                forceRedraw = true
            end)
        end
    elseif scene == READER then
        systemMenu:addMenuItem("Library", function() saveState() initLibrary(true) end)
        systemMenu:addMenuItem("Navigation", function()
            if not menuActive and not chapterMenuActive and not bookmarkMenuActive and not navMenuActive then
                if isPDB and #currentChapters > 0 then
                    openNavMenu()
                else
                    bookmarkMenuActive = true
                    initBookmarkMenu()
                    forceRedraw = true
                end
            end
        end)
        systemMenu:addMenuItem("Settings", function()
            if not menuActive and not chapterMenuActive and not bookmarkMenuActive and not navMenuActive then
                menuActive = true
                forceRedraw = true
            end
        end)
    end
end

local function drawCandle()
    local TOP = textProgress * (DEVICE_HEIGHT - candleTop.height - 10 - candleHolder.height) + 4
    local LEFT = DEVICE_WIDTH - 1 - candleSection.width
    candleTop:draw(LEFT, TOP)
    local timeInMilliseconds = playdate.getCurrentTimeMilliseconds()
    if timeInMilliseconds % 27 == 0 then
        if flame == candleFlameOne or flame == candleFlameThree then flame = candleFlameTwo
        elseif flame == candleFlameTwo then
            if math.random() < 0.6 then flame = candleFlameOne else flame = candleFlameThree end
        end
    end
    flame:draw(LEFT, TOP)
    local sections = floor((DEVICE_HEIGHT - TOP - candleTop.height) / candleSection.height) + 1
    for i = 1, sections do candleSection:draw(LEFT, TOP + candleTop.height + (i - 1) * candleSection.height) end
    candleHolder:draw(LEFT, DEVICE_HEIGHT - candleHolder.height)
    local bottom = DEVICE_HEIGHT - candleDripLeft.height + 4 - candleHolder.height
    candleDripLeft:draw(LEFT, min(bottom, TOP + 40 + textProgress * 115))
    candleDripRight:draw(LEFT + candleSection.width - candleDripRight.width, min(bottom, TOP + 90 + textProgress * 20))
end

local function drawScrollbar()
    local VERT_MARGIN = 2
    local LEFT = DEVICE_WIDTH - 2 - scrollbarSection.width
    scrollbarButton:draw(LEFT, VERT_MARGIN)
    scrollbarArrow:draw(LEFT + 2, VERT_MARGIN + 2)
    for i = 1, 17 do scrollbarSection:draw(LEFT, VERT_MARGIN + scrollbarButton.height + (i - 1) * scrollbarSection.height) end
    scrollbarButton:draw(LEFT, DEVICE_HEIGHT - VERT_MARGIN - scrollbarButton.height)
    scrollbarArrow:draw(LEFT + 2, DEVICE_HEIGHT - VERT_MARGIN - scrollbarButton.height + 3, graphics.kImageFlippedY)
    local progress = textProgress
    if progress <= 0.01 then progress = 0 elseif progress >= 0.99 then progress = 1 end
    local sliderY = VERT_MARGIN + scrollbarButton.height + floor(progress * (DEVICE_HEIGHT - VERT_MARGIN * 2 - scrollbarButton.height * 2 - scrollbarSlider.height))
    scrollbarSlider:draw(LEFT + 1, sliderY)
end

drawSkimOverlay = function()
    local boxW = 240
    local boxH = 120
    local bx = (DEVICE_WIDTH - boxW) / 2
    local by = (DEVICE_HEIGHT - boxH) / 2
    
    graphics.setColor(graphics.kColorWhite)
    graphics.fillRoundRect(bx, by, boxW, boxH, 8)
    graphics.setColor(graphics.kColorBlack)
    graphics.drawRoundRect(bx, by, boxW, boxH, 8)
    
    graphics.setImageDrawMode(graphics.kDrawModeCopy)
    graphics.setFont(graphics.getSystemFont())
    local pct = "*" .. math.floor(skimProgress * 100) .. "%*"
    graphics.drawTextAligned(pct, DEVICE_WIDTH / 2, by + 20, kTextAlignment.center)
    
    local minsRemaining = math.ceil((1 - skimProgress) * textLength / readingSpeed)
    local timeText = (minsRemaining > 60) and (math.floor(minsRemaining/60) .. "h " .. (minsRemaining%60) .. "m left") or (minsRemaining .. " mins left")
    graphics.drawTextAligned(timeText, DEVICE_WIDTH / 2, by + 55, kTextAlignment.center)
    
    if isPDB and #currentChapters > 0 then
        local currentChap = currentChapters[1].title
        local targetIndex = skimProgress * textLength
        for i=1, #currentChapters do
            if currentChapters[i].index <= targetIndex then currentChap = currentChapters[i].title else break end
        end
        graphics.drawTextAligned(currentChap, DEVICE_WIDTH / 2, by + 80, kTextAlignment.center)
    end
end

drawTutorialOverlay = function()
    local img = tutorialImages[tutorialStep]
    if img then
        img:draw(0, 0)
    else
        local bw, bh = 280, 140
        local bx = (DEVICE_WIDTH - bw) / 2
        local by = (DEVICE_HEIGHT - bh) / 2
        graphics.setColor(graphics.kColorWhite)
        graphics.fillRoundRect(bx, by, bw, bh, 8)
        graphics.setColor(graphics.kColorBlack)
        graphics.setLineWidth(2)
        graphics.drawRoundRect(bx, by, bw, bh, 8)
        graphics.setLineWidth(1)
        
        graphics.setImageDrawMode(graphics.kDrawModeCopy)
        graphics.setFont(graphics.getSystemFont())
        
        local text = ""
        if tutorialStep == 1 then text = "*Page Turn*\nA: Next Page\nB: Previous Page"
        elseif tutorialStep == 2 then text = "*Scroll*\nUp/Down D-Pad\nor Turn Crank"
        elseif tutorialStep == 3 then text = "*Save Bookmark*\nHold B for 0.6s"
        elseif tutorialStep == 4 then text = "*Fast Skim*\nHold Left + Turn Crank"
        elseif tutorialStep == 5 then text = "*Dictionary*\nHold Right + Turn Crank"
        elseif tutorialStep == 6 then text = "*Settings*\nPress System Menu Button\n(Options & Return to Library)"
        end
        
        graphics.drawTextAligned("*Tutorial Step " .. tutorialStep .. "/6*", DEVICE_WIDTH / 2, by + 15, kTextAlignment.center)
        graphics.drawTextInRect(text, bx + 10, by + 50, bw - 20, bh - 60, nil, nil, kTextAlignment.center)
        graphics.drawTextAligned("Press A or B to continue", DEVICE_WIDTH / 2, by + bh - 25, kTextAlignment.center)
    end
end

local function drawText()
    graphics.clear(graphics.kColorWhite)
    graphics.setFont(FONTS[readerFontId].font)
    
    selectableWords = {}
    local isGlossaryMode = playdate.buttonIsPressed(playdate.kButtonRight) and not isSkimming and not menuActive and not chapterMenuActive and not bookmarkMenuActive and not navMenuActive and not tutorialActive
    
    if #lines > 0 then
        local drawOffset = floor(offset) + topLinesHeightOffset
        local currentY = drawOffset
        local totalHeight = 0
        local topLineStart, topLineStop = nil, nil
        local topLineY, topLineHeight = 0, 1
        
        for i = 1, #lines do
            local line = lines[i]
            if currentY + line.height > 0 and currentY < DEVICE_HEIGHT then
                if topLineStart == nil then
                    topLineStart = line.start
                    topLineStop = line.stop
                    topLineY = currentY
                    topLineHeight = line.height
                end
                
                graphics.drawText(line.text, leftMargin, currentY)
                
                if isGlossaryMode and line.glossaryWords then
                    for j = 1, #line.glossaryWords do
                        local gw = line.glossaryWords[j]
                        insert(selectableWords, { fullWord = gw.fullWord, cleanWord = gw.cleanWord, def = gw.def, x = gw.x, y = currentY, w = gw.w, h = line.height })
                    end
                end
            end
            currentY = currentY + line.height
            totalHeight = totalHeight + line.height
        end
        
        if topLineStart ~= nil then
            indexAtTopOfScreen = topLineStart
            local offsetWithinLine = 0
            if topLineY < 0 then offsetWithinLine = -topLineY / topLineHeight end
            local progressWithinLine = (topLineStop - topLineStart) * offsetWithinLine
            textProgress = (topLineStart + progressWithinLine) / textLength
            
            if textProgress > 0.99 and currentBookKey then
                globalStats.finishedBooks[currentBookKey] = true
            end
            
            if lastSettleIndex ~= indexAtTopOfScreen then
                local bytesDiff = math.abs(indexAtTopOfScreen - lastSettleIndex)
                local timeDiff = playdate.getCurrentTimeMilliseconds() - lastSettleTime
                
                if bytesDiff > 50 and timeDiff > 2000 and timeDiff < 300000 and not tutorialActive then
                    local wpm = (bytesDiff / 6) / (timeDiff / 60000.0)
                    if wpm > 50 and wpm < 1000 then
                        globalStats.timeReadMs = (globalStats.timeReadMs or 0) + timeDiff
                        globalStats.bytesRead = (globalStats.bytesRead or 0) + bytesDiff
                        local currentSpeed = bytesDiff / (timeDiff / 60000.0)
                        readingSpeed = math.floor((readingSpeed * 0.8) + (currentSpeed * 0.2))
                    end
                end
                
                if bytesDiff > 50 then
                    lastSettleIndex = indexAtTopOfScreen
                    lastSettleTime = playdate.getCurrentTimeMilliseconds()
                end
            end
        end
        
        if drawOffset + 2 * lineHeight > 0 then
            local linesNeeded = ceil((drawOffset + 2 * lineHeight) / lineHeight)
            removeLines(prependLines(linesNeeded), true)
            forceRedraw = true
        end
        if drawOffset + totalHeight < DEVICE_HEIGHT then
            local linesNeeded = ceil((DEVICE_HEIGHT - (drawOffset + totalHeight)) / lineHeight)
            removeLines(appendLines(linesNeeded), false)
            forceRedraw = true
        end
    end
    
    if isGlossaryMode and #selectableWords > 0 then
        selectedWordIndex = math.max(1, math.min(selectedWordIndex, #selectableWords))
        local sel = selectableWords[selectedWordIndex]
        
        graphics.setLineWidth(2)
        for j=1, #selectableWords do graphics.drawLine(selectableWords[j].x, selectableWords[j].y + selectableWords[j].h, selectableWords[j].x + selectableWords[j].w, selectableWords[j].y + selectableWords[j].h) end
        
        graphics.setColor(graphics.kColorBlack)
        graphics.fillRoundRect(sel.x - 2, sel.y - 2, sel.w + 4, sel.h + 4, 4)
        graphics.setImageDrawMode(graphics.kDrawModeInverted)
        graphics.drawText(sel.fullWord, sel.x, sel.y)
        graphics.setImageDrawMode(graphics.kDrawModeCopy)
        
        graphics.setFont(FONTS[5].font)
        local defText = "*" .. sel.cleanWord .. "*: " .. sel.def
        local boxW, boxH = 300, 75
        local tooltipY = sel.y - boxH - 5
        if tooltipY < 0 then tooltipY = sel.y + sel.h + 5 end 
        local tooltipX = math.max(2, math.min(DEVICE_WIDTH - boxW - 2, sel.x + sel.w/2 - boxW/2))
        
        graphics.setColor(graphics.kColorWhite)
        graphics.fillRoundRect(tooltipX, tooltipY, boxW, boxH, 6)
        graphics.setColor(graphics.kColorBlack)
        graphics.drawRoundRect(tooltipX, tooltipY, boxW, boxH, 6)
        graphics.drawTextInRect(defText, tooltipX + 8, tooltipY + 8, boxW - 16, boxH - 16)
        
        graphics.setFont(FONTS[readerFontId].font)
    elseif not isGlossaryMode then
        selectedWordIndex = 1
    end
    
    local isBookmarked = false
    if currentBookmarks and #lines > 0 then
        local pageStart, pageEnd = indexAtTopOfScreen, lines[#lines].stop
        for i = 1, #currentBookmarks do
            if currentBookmarks[i].index >= pageStart and currentBookmarks[i].index <= pageEnd then
                isBookmarked = true break
            end
        end
    end
    if isBookmarked then
        local foldSize = 22
        graphics.setColor(graphics.kColorBlack)
        graphics.fillTriangle(0, 0, foldSize, 0, 0, foldSize)
        graphics.setColor(graphics.kColorWhite)
        graphics.fillTriangle(0, foldSize, foldSize, 0, foldSize, foldSize)
        graphics.setColor(graphics.kColorBlack)
        graphics.setLineWidth(2)
        graphics.drawLine(0, foldSize, foldSize, 0)
        graphics.drawLine(foldSize, 0, foldSize, foldSize)
        graphics.drawLine(foldSize, foldSize, 0, foldSize)
        graphics.setLineWidth(1)
    end
    
    if progressIndicator == 2 then drawCandle() elseif progressIndicator == 3 then drawScrollbar() end
end

local function drawBookGraphic(x, y, title, progress, selected)
    graphics.setFont(FONTS[1].font)
    if selected then graphics.setImageDrawMode(graphics.kDrawModeInverted) end
    local MAX_TEXT_WIDTH = 200
    local cutOffText = title
    while graphics.getTextSize(cutOffText) > MAX_TEXT_WIDTH and #cutOffText > 0 do cutOffText = sub(cutOffText, 1, #cutOffText - 1) end
    local marginX = 30
    if cutOffText ~= title then
        cutOffText = cutOffText .. "..."
        marginX = 25
    end
    bookImage:draw(x, y)
    graphics.drawText(cutOffText, x + marginX, y + 40)
    if progress > 0.001 then
        local bookmarkHeight = math.floor(progress * 10 + 0.5) * 3
        if selected then bookmarkBorderImage:draw(x + 250, y + 30 + bookmarkHeight)
        else bookmarkImage:draw(x + 250, y + 30 + bookmarkHeight) end
    end
    graphics.setImageDrawMode(graphics.kDrawModeCopy)
end

local function drawFolderHeader()
    if math.abs(visualFolderIndex - currentFolderIndex) > 0.005 then
        visualFolderIndex = visualFolderIndex + (currentFolderIndex - visualFolderIndex) * 0.4
        forceRedraw = true 
    else
        visualFolderIndex = currentFolderIndex
    end

    local headerHeight = 32
    local targetHeaderY = 0
    
    if currentFolderIndex == FOLDER_ALL_BOOKS then
        if not hasScrolledLibrary or (playdate.getCurrentTimeMilliseconds() - lastActivityTime > 2000) then
            targetHeaderY = -40
        end
    end
    
    headerYOffset = headerYOffset + (targetHeaderY - headerYOffset) * 0.15
    if math.abs(headerYOffset - targetHeaderY) > 0.5 then 
        forceRedraw = true 
    else 
        headerYOffset = targetHeaderY 
    end

    graphics.setColor(graphics.kColorWhite)
    graphics.fillRect(0, headerYOffset, DEVICE_WIDTH, headerHeight)
    graphics.setColor(graphics.kColorBlack)
    graphics.setLineWidth(2)
    graphics.drawLine(0, headerYOffset + headerHeight, DEVICE_WIDTH, headerYOffset + headerHeight)
    graphics.setLineWidth(1)
    
    graphics.setImageDrawMode(graphics.kDrawModeCopy)
    graphics.setFont(graphics.getSystemFont())
    local spacing = 240 
    local minVisible = floor(visualFolderIndex) - 1
    local maxVisible = ceil(visualFolderIndex) + 1
    
    for i = minVisible, maxVisible do
        local name = getFolderName(i)
        if name then
            local offsetStr = i - visualFolderIndex
            local centerX = (DEVICE_WIDTH / 2) + (offsetStr * spacing)
            local textWidth = graphics.getTextSize("*" .. name .. "*")
            local textX = centerX - (textWidth / 2)
            local textY = headerYOffset + 8
            
            graphics.drawText("*" .. name .. "*", textX, textY)
            
            if math.abs(offsetStr) < 0.1 and not isMovingBook then
                if i > FOLDER_IN_PROGRESS then
                    graphics.fillTriangle(textX - 16, textY + 7, textX - 8, textY + 3, textX - 8, textY + 11)
                end
                if i < (#globalStats.folders or 0) + 1 then
                    local rightEdge = textX + textWidth
                    graphics.fillTriangle(rightEdge + 16, textY + 7, rightEdge + 8, textY + 3, rightEdge + 8, textY + 11)
                end
            end
        end
    end
end

local function drawLibrary()
    graphics.clear(graphics.kColorWhite)
    
    if currentFolderIndex == #globalStats.folders + 1 then
        drawFolderHeader()
        
        if isKeyboardOpen then
            local kw, kh = 200, 60
            local kx, ky = 10, 40
            
            graphics.setColor(graphics.kColorBlack)
            graphics.fillRoundRect(kx + 4, ky + 4, kw, kh, 8)
            graphics.setColor(graphics.kColorWhite)
            graphics.fillRoundRect(kx, ky, kw, kh, 8)
            graphics.setColor(graphics.kColorBlack)
            graphics.drawRoundRect(kx, ky, kw, kh, 8)
            
            graphics.setImageDrawMode(graphics.kDrawModeCopy)
            graphics.setFont(graphics.getSystemFont())
            graphics.drawTextAligned("*New Folder Name:*", kx + kw/2, ky + 10, kTextAlignment.center)
            
            local textToDraw = playdate.keyboard.text
            if textToDraw == "" then textToDraw = "..." end
            if (playdate.getCurrentTimeMilliseconds() % 1000) > 500 then textToDraw = textToDraw .. "_" end
            graphics.drawTextAligned(textToDraw, kx + kw/2, ky + 34, kTextAlignment.center)
        else
            graphics.setImageDrawMode(graphics.kDrawModeCopy)
            graphics.setFont(graphics.getSystemFont())
            graphics.drawTextAligned("*Press A to Create Folder*", DEVICE_WIDTH/2, DEVICE_HEIGHT/2, kTextAlignment.center)
        end
        return
    end
    
    if math.abs(currentScrollOffset - targetScrollOffset) > 0.5 then
        currentScrollOffset = currentScrollOffset + (targetScrollOffset - currentScrollOffset) * 0.3
        forceRedraw = true
    else
        currentScrollOffset = targetScrollOffset
    end
    
    local headerOffset = 36
    local titleBottom = headerOffset
    
    if currentFolderIndex == FOLDER_ALL_BOOKS then
        titleAnimationProgress = math.min(1, titleAnimationProgress + 0.015)
        if titleAnimationProgress < 1 then forceRedraw = true end
        
        local titleOffset = -210 + easeOut(titleAnimationProgress) * 200
        local subtitleOffset = 240 - easeOut(titleAnimationProgress) * 250
        local titleY = headerOffset + 10 - currentScrollOffset
        
        if titleY > -100 and titleY < DEVICE_HEIGHT then
            if highlightedBook == nil or highlightedBook < 2 then
                titleImage:draw(DEVICE_WIDTH / 2 - titleImage.width / 2, titleY + titleOffset)
                
                graphics.setFont(FONTS[1].font)
                for i = 1, #subtitle do
                    local width, height = graphics.getTextSize(subtitle[i])
                    graphics.drawText(subtitle[i], DEVICE_WIDTH / 2 - width / 2, titleY + 40 + 20 * i + subtitleOffset)
                end
            end
        end
        titleBottom = headerOffset + 125
    else
        titleBottom = headerOffset + 20
    end
    
    if fallingBookProgress < 20000 then
        fallingBookProgress = fallingBookProgress + 20
        forceRedraw = true
    end

    -- Draw in physical overlapping stack order (Bottom books first, Book 1 last on top)
    for i = #availableBooks, 1, -1 do
        local book = availableBooks[i]
        local endY = titleBottom + BOOK_SEPARATION * (i - 1) - currentScrollOffset
        local currentY
        
        if currentFolderIndex == FOLDER_ALL_BOOKS then
            local panOffset = (1 - easeOut(titleAnimationProgress)) * 150
            currentY = endY + panOffset
        else
            if fallingBookProgress >= 20000 or i > 4 then
                currentY = endY
            else
                local maxAnim = math.min(#availableBooks, 4)
                local cascadeIndex = maxAnim - i + 1
                local fallingY = fallingBookProgress - (cascadeIndex * 150)
                currentY = math.min(endY, fallingY)
            end
        end
        
        if isMovingBook then
            if i < highlightedBook then
                currentY = currentY - 35
            elseif i > highlightedBook then
                currentY = currentY + 35
            end
        end
        
        if currentY + 103 > 32 and currentY < DEVICE_HEIGHT then
            if isMovingBook and floatingBook and book.name == floatingBook.name then
                -- Skip rendering dragged book in stack
            else
                local isHighlighted = (i == highlightedBook) and not isMovingBook
                local progress = (booksState[book.name] and booksState[book.name].progress) or 0
                local drawX = (i % 2 == 0) and 80 or 60
                drawBookGraphic(drawX, currentY, book.name, progress, isHighlighted)
            end
        end
    end
    
    if isMovingBook and floatingBook then
        local floatX, floatY = 70, 80
        local progress = (booksState[floatingBook.name] and booksState[floatingBook.name].progress) or 0
        drawBookGraphic(floatX, floatY, floatingBook.name, progress, true)
    end
    
    drawFolderHeader()
end

local menuScrollY = nil
local function drawMenu()
    graphics.clear()
    local menuWidth, optionRowHeight = 280, 28
    local targetY = (DEVICE_HEIGHT / 2) - ((activeSetting - 1) * optionRowHeight) - (optionRowHeight / 2)
    
    if menuScrollY == nil then menuScrollY = targetY end
    menuScrollY = menuScrollY + (targetY - menuScrollY) * 0.4
    
    if math.abs(menuScrollY - targetY) > 0.5 then forceRedraw = true
    else menuScrollY = targetY end
    
    for i = 1, #optionViews do
        local yPos = menuScrollY + (i - 1) * optionRowHeight
        if yPos > -optionRowHeight and yPos < DEVICE_HEIGHT then
            graphics.setImageDrawMode(graphics.kDrawModeCopy)
            graphics.setFont(graphics.getSystemFont())
            graphics.drawText("*" .. MENU_OPTIONS[i].label .. "*", (DEVICE_WIDTH - menuWidth) / 2, yPos + optionRowHeight / 2 - 11)
            optionViews[i]:drawInRect((DEVICE_WIDTH - menuWidth) / 2 + (menuWidth - OPTIONS_WIDTH), yPos, OPTIONS_WIDTH, optionRowHeight)
        end
    end
    graphics.setFont(FONTS[readerFontId].font)
end

drawNavMenu = function()
    graphics.setColor(graphics.kColorWhite)
    graphics.fillRoundRect(80, 50, 240, 140, 8)
    graphics.setColor(graphics.kColorBlack)
    graphics.drawRoundRect(80, 50, 240, 140, 8)
    
    graphics.setImageDrawMode(graphics.kDrawModeCopy)
    graphics.setFont(graphics.getSystemFont())
    graphics.drawTextAligned("*Navigation*", DEVICE_WIDTH/2, 60, kTextAlignment.center)
    
    navGridView:drawInRect(100, 85, 200, 95)
end

local function drawChapterMenu()
    graphics.setColor(graphics.kColorWhite)
    graphics.fillRoundRect(30, 20, 340, 200, 8)
    graphics.setColor(graphics.kColorBlack)
    graphics.drawRoundRect(30, 20, 340, 200, 8)
    chapterGridView:drawInRect(50, 35, 300, 170)
end

local function drawBookmarkMenu()
    graphics.setColor(graphics.kColorWhite)
    graphics.fillRoundRect(30, 20, 340, 200, 8)
    graphics.setColor(graphics.kColorBlack)
    graphics.drawRoundRect(30, 20, 340, 200, 8)
    bookmarkGridView:drawInRect(50, 35, 300, 170)
end

-----------------------------------------
-- INPUT HANDLING
-----------------------------------------

local function previousOption()
    optionViews[activeSetting]:selectPreviousColumn(true)
    local _, _, selCol = optionViews[activeSetting]:getSelection()
    MENU_OPTIONS[activeSetting].callback(selCol)
end

local function nextOption()
    optionViews[activeSetting]:selectNextColumn(true)
    local _, _, selCol = optionViews[activeSetting]:getSelection()
    MENU_OPTIONS[activeSetting].callback(selCol)
end

local function previousSetting()
    activeSetting = activeSetting - 1
    if activeSetting < 1 then activeSetting = #optionViews end
end

local function nextSetting()
    activeSetting = activeSetting + 1
    if activeSetting > #optionViews then activeSetting = 1 end
end

local function updateLibraryInputs()
    if isKeyboardOpen then return end

    if isMovingBook then
        if playdate.buttonJustPressed(playdate.kButtonRight) then
            local target = math.min(currentFolderIndex + 1, #globalStats.folders)
            if currentFolderIndex ~= target then
                currentFolderIndex = target
                hasScrolledLibrary = true
                updateFolderView(true) 
                forceRedraw = true
                lastActivityTime = playdate.getCurrentTimeMilliseconds()
            end
        elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
            local target = math.max(currentFolderIndex - 1, FOLDER_IN_PROGRESS)
            if currentFolderIndex ~= target then
                currentFolderIndex = target
                hasScrolledLibrary = true
                updateFolderView(true) 
                forceRedraw = true
                lastActivityTime = playdate.getCurrentTimeMilliseconds()
            end
        elseif playdate.buttonJustPressed(playdate.kButtonB) then
            isMovingBook = false floatingBook = nil forceRedraw = true
            lastActivityTime = playdate.getCurrentTimeMilliseconds()
        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            if currentFolderIndex > 0 and currentFolderIndex <= #globalStats.folders then
                insert(globalStats.folders[currentFolderIndex].books, floatingBook.name)
                saveState()
                isMovingBook = false floatingBook = nil
                updateFolderView(true) 
                forceRedraw = true
            end
            lastActivityTime = playdate.getCurrentTimeMilliseconds()
        end
        return
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        aPressStartTime = playdate.getCurrentTimeMilliseconds()
        isHoldingA = true
    end
    
    if isHoldingA and playdate.buttonIsPressed(playdate.kButtonA) then
        if playdate.getCurrentTimeMilliseconds() - aPressStartTime >= 1000 then
            isHoldingA = false
            if #availableBooks > 0 then
                isMovingBook = true
                floatingBook = availableBooks[highlightedBook]
                forceRedraw = true
            end
        end
    end
    
    if isHoldingA and playdate.buttonJustReleased(playdate.kButtonA) then
        isHoldingA = false
        if currentFolderIndex == #globalStats.folders + 1 then
            promptNewFolder()
        else
            if #availableBooks > 0 then loadBook(availableBooks[highlightedBook]) end
        end
    end
    
    if playdate.buttonJustPressed(playdate.kButtonRight) then
        local target = math.min(currentFolderIndex + 1, #globalStats.folders + 1)
        if currentFolderIndex ~= target then
            currentFolderIndex = target
            hasScrolledLibrary = true
            updateFolderView(false) 
            forceRedraw = true
            lastActivityTime = playdate.getCurrentTimeMilliseconds()
        end
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
        local target = math.max(currentFolderIndex - 1, FOLDER_IN_PROGRESS)
        if currentFolderIndex ~= target then
            currentFolderIndex = target
            hasScrolledLibrary = true
            updateFolderView(false) 
            forceRedraw = true
            lastActivityTime = playdate.getCurrentTimeMilliseconds()
        end
    elseif playdate.buttonJustPressed(playdate.kButtonUp) then
        local target = math.max(highlightedBook - 1, 1)
        if highlightedBook ~= target then
            highlightedBook = target
            hasScrolledLibrary = true
            updateTargetScroll()
            forceRedraw = true
            lastActivityTime = playdate.getCurrentTimeMilliseconds()
        end
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        local target = math.min(highlightedBook + 1, #availableBooks)
        if highlightedBook ~= target then
            highlightedBook = target
            hasScrolledLibrary = true
            updateTargetScroll()
            forceRedraw = true
            lastActivityTime = playdate.getCurrentTimeMilliseconds()
        end
    end
end

function playdate.gameWillPause()
    if scene == READER then
        local menuImg = graphics.getDisplayImage()
        graphics.pushContext(menuImg)
        local minsRemaining = math.ceil((1 - textProgress) * textLength / readingSpeed)
        local pct = math.floor(textProgress * 100)
        graphics.setImageDrawMode(graphics.kDrawModeCopy)
        graphics.setFont(graphics.getSystemFont())
        
        local rawTitle = currentBookKey or "Unknown Book"
        local maxTitleWidth = 150 
        local titleLines = {}
        local currLine = ""
        for word in string.gmatch(rawTitle, "%S+") do
            if currLine == "" then currLine = word
            elseif graphics.getTextSize("*" .. currLine .. " " .. word .. "*") <= maxTitleWidth then currLine = currLine .. " " .. word
            else insert(titleLines, currLine) currLine = word end
        end
        if currLine ~= "" then insert(titleLines, currLine) end
        
        if #titleLines > 2 then
            local lastLine = titleLines[2]
            while graphics.getTextSize("*" .. lastLine .. "...*") > maxTitleWidth and #lastLine > 0 do lastLine = string.sub(lastLine, 1, #lastLine - 1) end
            titleLines[2] = lastLine .. "..."
            while #titleLines > 2 do table.remove(titleLines) end
        end
        for i=1, #titleLines do
            if graphics.getTextSize("*" .. titleLines[i] .. "*") > maxTitleWidth then
                local safeStr = titleLines[i]
                while graphics.getTextSize("*" .. safeStr .. "...*") > maxTitleWidth and #safeStr > 0 do safeStr = string.sub(safeStr, 1, #safeStr - 1) end
                titleLines[i] = safeStr .. "..."
            end
        end
        
        local w0 = 0
        for i=1, #titleLines do
            local lw = graphics.getTextSize("*" .. titleLines[i] .. "*")
            if lw > w0 then w0 = lw end
        end
        local fontHeight = graphics.getSystemFont():getHeight()
        local h0 = fontHeight * #titleLines
        
        local line1 = pct .. "% Completed"
        local line2 = (minsRemaining > 60) and (math.floor(minsRemaining/60) .. "h " .. (minsRemaining%60) .. "m left") or (minsRemaining .. "m left")
        local w1, h1 = graphics.getTextSize("*"..line1.."*")
        local w2, h2 = graphics.getTextSize(line2)
        
        local boxW = math.max(w0, math.max(w1, w2)) + 24
        local boxH = h0 + h1 + h2 + 28 + ((#titleLines - 1) * 2) 
        local bx = 16
        local by = DEVICE_HEIGHT / 2 - boxH / 2
        
        graphics.setColor(graphics.kColorBlack) graphics.fillRoundRect(bx + 4, by + 4, boxW, boxH, 8)
        graphics.setColor(graphics.kColorWhite) graphics.fillRoundRect(bx, by, boxW, boxH, 8)
        graphics.setColor(graphics.kColorBlack) graphics.drawRoundRect(bx, by, boxW, boxH, 8)
        
        local currentY = by + 10
        for i=1, #titleLines do
            graphics.drawText("*" .. titleLines[i] .. "*", bx + 12, currentY)
            currentY = currentY + fontHeight + 2
        end
        local lineY = currentY + 2
        graphics.drawLine(bx + 12, lineY, bx + boxW - 12, lineY)
        graphics.drawText("*"..line1.."*", bx + 12, lineY + 6)
        graphics.drawText(line2, bx + 12, lineY + 6 + h1 + 2)
        
        graphics.popContext()
        playdate.setMenuImage(menuImg)
    else
        playdate.setMenuImage(nil)
    end
end

function playdate.update()
    if playdate.getCurrentTimeMilliseconds() - lastActivityTime > 2000 then playdate.display.setRefreshRate(10) end
    
    if scene == LIBRARY then
        if isKeyboardOpen then forceRedraw = true end
        
        if currentFolderIndex == FOLDER_ALL_BOOKS and headerYOffset > -39.5 then
            if playdate.getCurrentTimeMilliseconds() - lastActivityTime > 2000 then
                forceRedraw = true
            end
        end
        
        updateLibraryInputs()
        if forceRedraw then 
            forceRedraw = false
            drawLibrary() 
        end
        
    elseif scene == READER then
        if navMenuActive then
            if playdate.buttonJustPressed(playdate.kButtonUp) then navGridView:selectPreviousRow(true) end
            if playdate.buttonJustPressed(playdate.kButtonDown) then navGridView:selectNextRow(true) end
        elseif chapterMenuActive then
            if playdate.buttonJustPressed(playdate.kButtonUp) then chapterGridView:selectPreviousRow(true) end
            if playdate.buttonJustPressed(playdate.kButtonDown) then chapterGridView:selectNextRow(true) end
        elseif bookmarkMenuActive then
            if playdate.buttonJustPressed(playdate.kButtonUp) then bookmarkGridView:selectPreviousRow(true) end
            if playdate.buttonJustPressed(playdate.kButtonDown) then bookmarkGridView:selectNextRow(true) end
        elseif menuActive then
            if playdate.buttonJustPressed(playdate.kButtonUp) then previousSetting() end
            if playdate.buttonJustPressed(playdate.kButtonDown) then nextSetting() end
            if playdate.buttonJustPressed(playdate.kButtonLeft) then previousOption() end
            if playdate.buttonJustPressed(playdate.kButtonRight) then nextOption() end
        elseif benchmarkText then
            -- Wait for press
        elseif tutorialActive then
            -- Shield input while tutorial runs
        elseif isSkimming then
            if not playdate.buttonIsPressed(playdate.kButtonLeft) then
                isSkimming = false
                local targetIndex = math.max(1, math.floor(skimProgress * textLength))
                lines = {} emptyLinesAbove = 0 offset = 0
                initializeLines(targetIndex)
                forceRedraw = true
            else sound:setVolume(0) end
        elseif playdate.buttonIsPressed(playdate.kButtonRight) then
            -- Glossary
        else
            if isHoldingB and playdate.buttonIsPressed(playdate.kButtonB) then
                if playdate.getCurrentTimeMilliseconds() - bPressStartTime >= 600 then
                    isHoldingB = false
                    bWasHeld = true
                    toggleBookmark()
                    sound:playNote(1200)
                end
            end

            offset = offset + directionHeld * BTN_SCROLL_SPEED
            local vol = min(abs(playdate.getCrankChange() * VOLUME_ACCELERATION * MAX_VOLUME), MAX_VOLUME)
            if skipSoundTicks > 0 then skipSoundTicks = skipSoundTicks - 1 else sound:setVolume(vol) end
            
            local isMoving = (offset ~= lastOffset) or forceRedraw
            if isMoving and not wasMoving then
                local timeSpentMs = playdate.getCurrentTimeMilliseconds() - lastSettleTime
                local bytesRead = indexAtTopOfScreen - lastSettleIndex
                
                if bytesRead > 20 and timeSpentMs > 2000 and timeSpentMs < 300000 and not tutorialActive then
                    local wpm = (bytesDiff / 6) / (timeDiff / 60000.0)
                    if wpm > 50 and wpm < 1000 then
                        globalStats.timeReadMs = (globalStats.timeReadMs or 0) + timeSpentMs
                        globalStats.bytesRead = (globalStats.bytesRead or 0) + bytesRead
                        local currentSpeed = bytesRead / (timeSpentMs / 60000.0)
                        readingSpeed = math.floor((readingSpeed * 0.8) + (currentSpeed * 0.2))
                    end
                end
            elseif not isMoving and wasMoving then
                lastSettleTime = playdate.getCurrentTimeMilliseconds()
                lastSettleIndex = indexAtTopOfScreen
            end
            wasMoving = isMoving
        end
        
        if offset ~= lastOffset or forceRedraw or isSkimming or tutorialActive then
            forceRedraw = false
            drawText()
            if isSkimming then drawSkimOverlay() end
            if tutorialActive then drawTutorialOverlay() end
            lastOffset = offset
        end
        if benchmarkText then drawBenchmarkOverlay() end
    end
    
    if menuActive then drawMenu() end
    if navMenuActive then drawNavMenu() end
    if chapterMenuActive then drawChapterMenu() end
    if bookmarkMenuActive then drawBookmarkMenu() end
    playdate.timer.updateTimers()
end

function playdate.cranked(change, acceleratedChange)
    registerActivity()
    if isKeyboardOpen then return end
    if tutorialActive then return end
    if scene == LIBRARY then
        local ticks = playdate.getCrankTicks(4)
        if ticks == 1 then
            local target = math.min(highlightedBook + 1, #availableBooks)
            if highlightedBook ~= target then
                highlightedBook = target
                hasScrolledLibrary = true
                updateTargetScroll()
                forceRedraw = true
            end
        elseif ticks == -1 then
            local target = math.max(highlightedBook - 1, 1)
            if highlightedBook ~= target then
                highlightedBook = target
                hasScrolledLibrary = true
                updateTargetScroll()
                forceRedraw = true
            end
        end
    elseif scene == READER then
        if benchmarkText then return end
        if navMenuActive then
            local ticks = playdate.getCrankTicks(8)
            if ticks == 1 then navGridView:selectNextRow(true) elseif ticks == -1 then navGridView:selectPreviousRow(true) end
        elseif menuActive then
            local ticks = playdate.getCrankTicks(8)
            if ticks == 1 then nextSetting() elseif ticks == -1 then previousSetting() end
        elseif chapterMenuActive then
            local ticks = playdate.getCrankTicks(8)
            if ticks == 1 then chapterGridView:selectNextRow(true) elseif ticks == -1 then chapterGridView:selectPreviousRow(true) end
        elseif bookmarkMenuActive then
            local ticks = playdate.getCrankTicks(8)
            if ticks == 1 then bookmarkGridView:selectNextRow(true) elseif ticks == -1 then bookmarkGridView:selectPreviousRow(true) end
        elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
            if not isSkimming then isSkimming = true skimProgress = textProgress end
            skimProgress = math.max(0, math.min(1, skimProgress + (change / 360) * 0.05))
            forceRedraw = true
        elseif playdate.buttonIsPressed(playdate.kButtonRight) then
            if selectableWords and #selectableWords > 0 then
                local ticks = playdate.getCrankTicks(8)
                if ticks == 1 then
                    selectedWordIndex = selectedWordIndex + 1
                    if selectedWordIndex > #selectableWords then selectedWordIndex = 1 end
                    forceRedraw = true
                elseif ticks == -1 then
                    selectedWordIndex = selectedWordIndex - 1
                    if selectedWordIndex < 1 then selectedWordIndex = #selectableWords end
                    forceRedraw = true
                end
            end
        else
            if skipScrollTicks > 0 then
                skipScrollTicks = skipScrollTicks - 1
                offset = offset - previousCrankOffset
            else
                offset = offset - change * CRANK_SCROLL_SPEED * crankSpeedModifier
                previousCrankOffset = change * CRANK_SCROLL_SPEED * crankSpeedModifier
            end
        end
    end
end

function playdate.upButtonDown()
    registerActivity()
    if tutorialActive then return end
    if scene == READER then if not menuActive and not chapterMenuActive and not bookmarkMenuActive and not navMenuActive and not benchmarkText then directionHeld = 1 end end
end
function playdate.upButtonUp() directionHeld = 0 end

function playdate.downButtonDown()
    registerActivity()
    if tutorialActive then return end
    if scene == READER then if not menuActive and not chapterMenuActive and not bookmarkMenuActive and not navMenuActive and not benchmarkText then directionHeld = -1 end end
end
function playdate.downButtonUp() directionHeld = 0 end

function playdate.leftButtonDown() registerActivity() end
function playdate.rightButtonDown() registerActivity() if scene == READER then forceRedraw = true end end
function playdate.rightButtonUp() registerActivity() if scene == READER then forceRedraw = true end end

function playdate.AButtonDown()
    registerActivity()
    
    if scene == READER then
        if tutorialActive then
            tutorialStep = tutorialStep + 1
            if tutorialStep > 6 then
                tutorialActive = false
                tutorialCompleted = true
                saveState()
            end
            forceRedraw = true
            return
        end
        if benchmarkText then benchmarkText = nil forceRedraw = true return
        elseif navMenuActive then
            local _, row, _ = navGridView:getSelection()
            local action = navOptions[row].action
            navMenuActive = false
            if action == "chapters" then chapterMenuActive = true
            elseif action == "bookmarks" then bookmarkMenuActive = true initBookmarkMenu() end
            forceRedraw = true
        elseif menuActive then menuActive = false forceRedraw = true
        elseif chapterMenuActive then
            local _, row, _ = chapterGridView:getSelection()
            local targetIndex = currentChapters[row].index
            lines = {} emptyLinesAbove = 0 offset = 0
            initializeLines(targetIndex)
            chapterMenuActive = false forceRedraw = true
        elseif bookmarkMenuActive then
            if #currentBookmarks > 0 then
                local _, row, _ = bookmarkGridView:getSelection()
                local targetIndex = currentBookmarks[row].index
                lines = {} emptyLinesAbove = 0 offset = 0
                initializeLines(targetIndex)
            end
            bookmarkMenuActive = false forceRedraw = true
        elseif isSkimming or playdate.buttonIsPressed(playdate.kButtonRight) then
            -- Do nothing
        else
            local pageHeight = math.floor(DEVICE_HEIGHT / lineHeight) * lineHeight
            offset = math.ceil((offset - pageHeight) / lineHeight) * lineHeight
            forceRedraw = true
        end
    end
end

function playdate.BButtonDown()
    registerActivity()
    
    if scene == READER then 
        if tutorialActive then
            tutorialStep = tutorialStep + 1
            if tutorialStep > 6 then
                tutorialActive = false
                tutorialCompleted = true
                saveState()
            end
            forceRedraw = true
            return
        end
        if benchmarkText then benchmarkText = nil forceRedraw = true return
        elseif navMenuActive then navMenuActive = false forceRedraw = true
        elseif menuActive then menuActive = false forceRedraw = true
        elseif chapterMenuActive then chapterMenuActive = false forceRedraw = true
        elseif bookmarkMenuActive then bookmarkMenuActive = false forceRedraw = true
        elseif isSkimming or playdate.buttonIsPressed(playdate.kButtonRight) then
            -- Do nothing
        else
            bPressStartTime = playdate.getCurrentTimeMilliseconds()
            isHoldingB = true
            bWasHeld = false
        end
    end
end

function playdate.BButtonUp()
    if isHoldingB then
        isHoldingB = false
        if not bWasHeld then
            local pageHeight = math.floor(DEVICE_HEIGHT / lineHeight) * lineHeight
            offset = math.floor((offset + pageHeight) / lineHeight) * lineHeight
            if offset > 0 and lines[1] and lines[1].start <= 1 then offset = 0 end
            forceRedraw = true
        end
    end
end

function playdate.gameWillTerminate() saveState() end
function playdate.deviceWillSleep() saveState() end
function playdate.deviceWillLock() saveState() end

local function init()
    playdate.display.setRefreshRate(50)
    registerActivity()
    loadState()
    graphics.setFont(FONTS[readerFontId].font)
    graphics.setBackgroundColor(graphics.kColorWhite)
    setInverted(inverted)
    
    initLibrary(false, true) 

    if scene == LIBRARY and lastBookKey ~= nil then
        for i = 1, #masterLibrary do
            if masterLibrary[i].name == lastBookKey then
                loadBook(masterLibrary[i])
                break
            end
        end
    end
end

init()