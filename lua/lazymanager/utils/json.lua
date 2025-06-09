--- JSON utilities for LazyManager.
-- @module lazymanager.utils.json
-- Provides pretty-printing, file read, and file write helpers for JSON data.

local M = {}

--- Pretty-print a Lua table as indented JSON.
-- @param tbl table: The table to pretty-print.
-- @param indent number: Indentation level (default 2).
-- @return string: JSON string.
function M.pretty(tbl, indent)
	indent = indent or 2
	local function quote(str)
		return '"' .. tostring(str):gsub('"', '\\"') .. '"'
	end
	local function is_array(t)
		local i = 0
		for _ in pairs(t) do
			i = i + 1
			if t[i] == nil then
				return false
			end
		end
		return true
	end
	local function dump(t, level)
		level = level or 0
		local pad = string.rep(" ", level * indent)
		if type(t) ~= "table" then
			if type(t) == "string" then
				return quote(t)
			else
				return tostring(t)
			end
		end
		local isarr = is_array(t)
		local items = {}
		for k, v in pairs(t) do
			local key = isarr and "" or (quote(k) .. ": ")
			table.insert(items, pad .. string.rep(" ", indent) .. key .. dump(v, level + 1))
		end
		if isarr then
			return "[\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "]"
		else
			return "{\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "}"
		end
	end
	return dump(tbl, 0)
end

--- Read and parse a JSON file.
-- @param file_path string: Path to the JSON file.
-- @return table|nil, string|nil: Table if successful, or nil and error message.
function M.read_file(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil, "Could not open file: " .. file_path
	end

	local content = file:read("*a")
	file:close()

	local ok, data = pcall(vim.fn.json_decode, content)
	if not ok then
		return nil, "Invalid JSON in file: " .. file_path
	end

	return data
end

--- Write a table to a JSON file.
-- @param file_path string: Path to the JSON file.
-- @param data table: Table to write.
-- @param indent number|nil: Indentation level (default 2).
-- @return boolean, string|nil: True if successful, or false and error message.
function M.write_file(file_path, data, indent)
	local json = M.pretty(data, indent or 2)
	local file = io.open(file_path, "w")

	if not file then
		return false, "Could not create file: " .. file_path
	end

	file:write(json)
	file:close()
	return true
end

return M
