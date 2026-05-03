-- Global push-to-toggle dictation.
-- Hotkey: Option+Cmd+D
--   1st press: start recording
--   2nd press: stop, transcribe via whisper.cpp, paste into focused app

local DICTATE_TOGGLE = os.getenv("HOME") .. "/.local/bin/dictate-toggle"
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

hs.alert.show("hammerspoon: dictation hotkey ready (⌥⌘D)", 1.5)
