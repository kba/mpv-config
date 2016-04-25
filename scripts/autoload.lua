-- This script automatically loads playlist entries before and after the
-- the currently played file. It does so by scanning the directory a file is
-- located in when starting playback. It sorts the directory entries
-- alphabetically, and adds entries before and after the current file to
-- the internal playlist. (It stops if the file it would add an already
-- existing playlist entry at the same position - this makes it "stable".)

--luacheck: globals mp
mputils = require 'mp.utils'

-- Add at most 5 * 2 files when starting a file (before + after).
MAXENTRIES = 5
AUTOLOADED = false
EXTENSIONS = {
    'mkv', 'avi', 'mp4', 'ogv', 'webm', 'rmvb', 'flv', 'wmv', 'mpeg', 'mpg', 'm4v', '3gp',
    'mp3', 'wav', 'ogv', 'flac', 'm4a', 'wma',
}
local FIND_TIMEOUT = 10

--
--
-- Utility functions
--
--
function string_ends(String, End)
   return End=='' or string.sub(String,-string.len(End))==End
end

function string_starts(String, End)
   return Start=='' or string.sub(String,0,String.len(End))==End
end

function add_files_at(index, files)
    index = index - 1
    local oldcount = mp.get_property_number("playlist-count", 1)
    for i = 1, #files do
        mp.commandv("loadfile", files[i], "append")
        mp.commandv("playlist_move", oldcount + i - 1, index + i - 1)
    end
end

-- function get_extension(path) , no unused
--     return string.match(path, "%.([^%.]+)$" )
-- end

-- table_filter = function(t, iter)
--     for i = #t, 1, -1 do
--         if not iter(t[i]) then
--             table.remove(t, i)
--         end
--     end
-- end



--- Build the file name clauses of the find call.
function build_clauses()
    local clauses = {}
    for i = 1, #EXTENSIONS do
        table.insert(clauses, "-name '*." .. EXTENSIONS[i] .. "'")
    end
    return table.concat(clauses, ' -o ')
end

--- Execute the find call.
-- @return the list of files
-- @return the playlist index of the current file
function exec_find(filename, basedir, maxdepth)
    basedir = basedir or '.'
    maxdepth = maxdepth or 1

    local files = {}
    local find_cmd = {
        'timeout', FIND_TIMEOUT,
        'find', basedir, '-maxdepth', maxdepth,
        build_clauses()
    }
    local cmd = table.concat(find_cmd, ' ')
    -- print(cmd)
    local f = io.popen(cmd)
    for line in f:lines() do
        -- remove './' from beginning of path if exists
        if string_starts(line, './') then
            line = string.sub(line, 3)
        end
        table.insert(files, line)
    end
    f:close()

    -- Find the current playlist entry (dir+"/"+filename) in the sorted dir list
    for i = 1, #files do
        if string_ends(files[i], filename) then
            -- print(files[i] .. ' =============== ' .. filename)
            return files, i
        end
    end
    return files, nil
end

function find_and_add_entries()
    local playlist_count = mp.get_property_native("playlist-count")

    -- If the playlist contains only one file -> started mpv with one file
    -- If it contains more and mpv did not start with one file -> leave playlist alone
    if playlist_count == 1 then
        AUTOLOADED = true
    elseif not AUTOLOADED then
        return
    end

    local path = mp.get_property("path", "")
    local dir, filename = mputils.split_path(path)
    if dir == '.' then
        dir = ''
    end

    local files, current = exec_find(filename, '.', 1)
    if #files == 1 then
        print("Looking in parent dir")
        files, current = exec_find(filename, '..', 2)
    end
    print (current .. ' / ' .. #files)

    -- current = current or 1
    local playlist = mp.get_property_native("playlist", {})
    local playlist_current = mp.get_property_number("playlist-pos", 0) + 1
    print(playlist_current)
    local append = {[-1] = {}, [1] = {}}
    for direction = -1, 1, 2 do -- 2 iterations, with direction = -1 and +1
        for i = 1, MAXENTRIES do
            local file = files[current + i * direction]
            local playlist_e = playlist[playlist_current + i * direction]
            if file == nil or file[1] == "." then
                break
            end

            local filepath = dir .. file
            if playlist_e then
                -- If there's a playlist entry, and it's the same file, stop.
                if playlist_e.filename == filepath then
                    break
                end
            end

            if direction == -1 then
                if playlist_current == 1 then -- never add additional entries in the middle
                    mp.msg.info("Prepending " .. file)
                    table.insert(append[-1], 1, filepath)
                end
            else
                -- mp.msg.info("Adding " .. file)
                table.insert(append[1], filepath)
            end
        end
    end

    add_files_at(playlist_current + 1, append[1])
    add_files_at(playlist_current, append[-1])
end

mp.register_event("start-file", find_and_add_entries)
