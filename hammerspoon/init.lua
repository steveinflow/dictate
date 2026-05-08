-- Global push-to-toggle dictation + speak-selection.
-- ⌥⌘D: 1st press start recording, 2nd press stop + transcribe + paste.
-- ⌥⌘S: speak the currently selected text via Kokoro; press again to stop.

local DICTATE_TOGGLE = os.getenv("HOME") .. "/.local/bin/dictate-toggle"
local SPEAK = os.getenv("HOME") .. "/.local/bin/speak"
local PID_FILE = (os.getenv("TMPDIR") or "/tmp/") .. "dictate-toggle/ffmpeg.pid"

local function isRecording()
    local f = io.open(PID_FILE, "r")
    if not f then return false end
    local pid = f:read("*l")
    f:close()
    if not pid or pid == "" then return false end
    return os.execute("kill -0 " .. pid .. " 2>/dev/null")
end

local function pasteText(text)
    local prev = hs.pasteboard.getContents()
    hs.pasteboard.setContents(text)
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    hs.timer.doAfter(0.6, function()
        if prev then hs.pasteboard.setContents(prev) end
    end)
end

local function toggleDictation()
    local recordingBefore = isRecording()
    if not recordingBefore then
        hs.alert.closeAll()
        hs.alert.show("dictating...", { textSize = 14 }, 0.6)
    else
        hs.alert.closeAll()
        hs.alert.show("transcribing...", { textSize = 14 }, 1.5)
    end

    hs.task.new("/bin/zsh", function(exitCode, stdOut, stdErr)
        if exitCode == 0 and stdOut and stdOut ~= "" then
            pasteText(stdOut)
        elseif exitCode ~= 0 then
            hs.alert.closeAll()
            hs.alert.show("dictate: " .. (stdErr or "error"), 2)
        end
    end, { "-lc", DICTATE_TOGGLE }):start()
end

hs.hotkey.bind({ "alt", "cmd" }, "d", toggleDictation)

local speakTask = nil

local function speakSelection()
    if speakTask and speakTask:isRunning() then
        speakTask:terminate()
        speakTask = nil
        hs.alert.closeAll()
        hs.alert.show("speak: stopped", { textSize = 14 }, 0.6)
        return
    end

    local prev = hs.pasteboard.getContents()
    hs.pasteboard.clearContents()
    hs.eventtap.keyStroke({ "cmd" }, "c", 0)

    -- Wait for the focused app to populate the pasteboard, then read it.
    hs.timer.doAfter(0.15, function()
        local text = hs.pasteboard.getContents()
        if prev then hs.pasteboard.setContents(prev) end

        if not text or text:gsub("%s+", "") == "" then
            hs.alert.show("speak: nothing selected", 1.0)
            return
        end

        hs.alert.closeAll()
        hs.alert.show("speaking...", { textSize = 14 }, 0.6)

        speakTask = hs.task.new("/bin/zsh", function(exitCode, _, stdErr)
            speakTask = nil
            -- 143 = SIGTERM (we asked it to stop); anything else is a real error.
            if exitCode ~= 0 and exitCode ~= 143 then
                hs.alert.show("speak: " .. (stdErr or "error"), 2)
            end
        end, { "-lc", "exec " .. SPEAK })
        speakTask:setInput(text)
        speakTask:start()
    end)
end

hs.hotkey.bind({ "alt", "cmd" }, "s", speakSelection)

hs.alert.show("hammerspoon: dictate ⌥⌘D · speak ⌥⌘S", 1.5)
