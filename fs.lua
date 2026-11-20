local M = {}

-- These functions are implementations for the 4 types of operation a user can
-- request using oil: deletion, creation, copying and renaming. They take both the
-- name of the entry they're operating on and the full qualified path (taking two
-- for renaming and copying). They true if they executed successfully, otherwise
-- returning `fail` and an error string. If any of these fail they might leave the
-- cwd in a state of impartial application, where some commands ran successfully thus
-- creating/deleting/copying/renaming/moving files while others did not run at all.
-- Thus instance:apply_changes or any function handling applications should scrap
-- whatever modification the user provided and redraw the instance as if it was just
-- opened with instance:insert_data. See comments on M.copy for more info.

-- TODO: Obvious optimizations would be having these command be run with vis:communicate.
--       Since I don't expect that many commands to be run in oil, it's fine with popen,
--       if you start slowing down... you probably shouldn't use oil. Still, could be done.
-- TODO: Make this functions available for changes. Like oil:map_open_buffer, with custom 
--       callbacks. This should solve the problem users with non-posix shells (that,
--       for example, do not undestand 2>&1), namely windows, or in general have them do
--       whatever they want if they don't like the default implementation. For that these
--       default implementations should be available as actions or be returned by the
--       'map_open_buffer'-like functions

function M.delete(entry_name, fullpath)
  local handle = io.popen(string.format('rm -rf -- "%s" 2>&1', fullpath))
  if not handle then
    return false, "Could not remove entry '" .. entry_name .. "'"
  end
  local output = handle:read("a")
  output = Utils.string_trim(output)
  local ok, how, int = handle:close()
  if not ok then
    if how == "exit" then
      return false, string.format("Error deleting entry '%s': %s", entry_name, output)
    else
      return false, string.format("Removal process for entry '%s' interrupted with signal %d", entry_name, int)
    end
  end
  return true;
end

-- NOTE/TODO: If the user tries to create both a file and a file within a directory
-- with the same name as the former, oil won't complain. The complaining will
-- happen when oil actually runs the commands. They will, at some point, recognise
-- the problem and stop with an error originating from here. The only solution for
-- this would be to have proper deduplication, but that would require a tree representation
-- of the cwd, so that non-superficial conflicting changes get recognized. To keep things
-- simple, my implementation lets the creation command complain during the applying process,
-- but that has the drawback of leaving unfinished applications (I.E. some files will be created
-- some won't). A fix for this would be having oil run these commands on a copy of the cwd in a 
-- /tmp/ directory and then re-copy the directory contents in oil cwd only if all modifications
-- were applied successfully. The drawback to that is that it would have to copy the ENTIRE cwd
-- RECURSIVELY.
-- For this simple implementation we signal such predicament to the user by simply redrawing the
-- cwd contents instead of returning to the 'modification state' buffer, hence removing some
-- of the (maybe correct) modification the user requested, as with all other functions. Check
-- comments on the top of this file (fs.lua)
function M.create(entry_name, fullpath)
  local dir, file = fullpath:match("^(.-)/?([^/]*)$")
  assert(dir, "Bug: fullpath is not a valid path string somehow")
  if dir and dir ~= "" then -- Should be almost always true
    local handle = io.popen(string.format('mkdir -p "%s" 2>&1', dir))
    if not handle then
      return false, "Could not create entry '" .. entry_name .. "'"
    end
    local output = handle:read("a")
    output = Utils.string_trim(output)
    local ok, how, int = handle:close()
    if not ok then
      if how == "exit" then
        return false, string.format("Error creating entry '%s': %s", entry_name, output)
      else
        return false, string.format("Creation process for entry '%s' interrupted with signal %d", entry_name, int)
      end
    end
  end
  if file ~= "" then -- Should be true only when creating files
    -- Decided to use touch and not io.open for consistency
    local handle = io.popen(string.format('touch "%s" 2>&1', fullpath))
    if not handle then
      return false, "Could not create entry '" .. entry_name .. "'"
    end
    local output = handle:read("a")
    output = Utils.string_trim(output)
    local ok, how, int = handle:close()
    if not ok then
      if how == "exit" then
        return false, string.format("Error creating entry '%s': %s", entry_name, output)
      else
        return false, string.format("Creation process for entry '%s' interrupted with signal %d", entry_name, int)
      end
    end
  end
  return true;
end

function M.copy(src_name, src, out_name, out)
  local handle = io.popen(string.format('cp --update=none-fail -a -- "%s" "%s" 2>&1', src, out))
  if not handle then
    return false, "Could not copy entry '" .. src_name .. "' -> '" .. out_name .. "'"
  end
  local output = handle:read("a")
  output = Utils.string_trim(output)
  local ok, how, int = handle:close()
  if not ok then
    if how == "exit" then
      return false, string.format("Error copying entry '%s' -> '%s': %s", src_name, out_name, output)
    else
      return false, string.format("Copy process to '%s' interrupted with signal %d", out_name, int)
    end
  end
  return true;
end

function M.move(from_name, from, into_name, into)
  local handle = io.popen(string.format('mv -n -- "%s" "%s"', from, into))
  if not handle then
    return false, "Could not rename entry '" .. from_name .. "' -> '" .. into_name .. "'"
  end
  local output = handle:read("a")
  output = Utils.string_trim(output)
  local ok, how, int = handle:close()
  if not ok then
    if how == "exit" then
      return false, string.format("Error renaming entry '%s' -> '%s': %s", from_name, into_name, output)
    else
      return false, string.format("Renaming process from '%s' into '%s' interrupted with signal %d", from_name, into_name, int)
    end
  end
  return true;
end

function M.deduplicate(cache, filename)
      local name_for_deduplication =
        filename:sub(-1) == "/" and filename:sub(1, -2) or filename
      if cache[name_for_deduplication] then
        return false, name_for_deduplication
      end
      cache[name_for_deduplication] = true
      return true, name_for_deduplication
end

return M
