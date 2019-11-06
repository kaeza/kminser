
---
-- KMinSer - Data serialization with minification.
--
-- This module contains functions to serialize values to strings, and
-- deserialize these strings back to values. It is able to serialize
-- strings, numbers, booleans, nil values, and tables.
--
-- Please note that not all tables can be serialized:
--
-- * For keys, only strings, numbers, and booleans are supported. For values,
--   tables are supported in addition to the types for keys. An unsupported
--   type will cause `dump` to return nil.
-- * Tables containing circular references will cause `dump` to return nil.
-- * Tables referenced more than once in the tree will be serialized separately
--   each time, and will result in references to different tables.
--
-- If a table has a `__minser` metamethod, the method is called passing it the
-- table itself and a table to cache seen sub-tables. The method should use the
-- `repr` function for sub fields, passing it the "seen" table.
--
-- The serialized output is a chunk of Lua code yielding comparable values.
--
-- The module does its best to generate the most compact code possible.
--
-- Tables with consecutive numerical indices starting from 1 ("arrays") are
-- efficiently stored by omitting the key. Numerical indices after the first
-- nil element are output adorned.
--
--     local t = { 42, "Hello!", nil, "blah" }
--     print(dump(t)) --> {42,"Hello!",[4]="blah"}
--
-- Keys that are considered valid identifiers are output unadorned; other keys
-- (including reserved words) are serialized as `[key]`.
--
--     local t = { a=1, ["b"]=2, c=3 }
--     t["true"] = true
--     -- Note that this is just an example; the order of non-array
--     -- fields is random, so they may not appear as shown here.
--     print(serialize(t)) --> {a=1,b=2,c=3,["true"]=true}
--
-- A key is a valid identifier if and only if all the following are true:
--
-- * It is a string, and is not empty.
-- * It consists of only letters, digits, or the underscore. Note that
--   since what Lua considers a "letter" or "digit" depends on the locale,
--   we take a shortcut and only take into account ASCII letters and digits.
-- * It does not begin with a digit.
-- * It is not a reserved word as listed in the [*Lexical Conventions*][lualc]
--   section of the manual for Lua 5.3.
--
-- The serialization algorithm only inserts a comma if needed, and it doesn't
-- add any spaces. The serialized data does not contain the `return` statement,
-- so this must be added if needed. The `load` function provided by this module
-- takes care of adding it if needed.
--
-- [lualc]: https://www.lua.org/manual/5.3/manual.html#3.1
--
-- @module kminser
-- @author Diego Martínez <https://github.com/kaeza>
-- @license MIT. See `LICENSE.md` for details.

local kminser = { }

-- Function defined below.
local reprtable

-- List of reserved words in the Lua language. Taken from section
-- 3.1 "Lexical Conventions" in the manual for Lua 5.3.
local reserved = {
	"and", "break", "do", "else", "elseif", "end", "false", "for",
	"function", "goto", "if", "in", "local", "nil", "not", "or",
	"repeat", "return", "then", "true", "until", "while",
}

-- Convert array to mapping for more efficient use.
for i, k in ipairs(reserved) do
	reserved[i] = nil
	reserved[k] = true
end

-- Check if a key is a valid identifier.
local function isvalidkey(k)
	return not (k=="" or reserved[k]
			or k:find("^[0-9]")
			or k:find("[^A-Za-z0-9_]"))
end

-- Return the representation of a key.
local function reprkey(k)
	local t = type(k)
	if t == "string" then
		if isvalidkey(k) then
			return k
		else
			return (("[%q]"):format(k)
					:gsub("\\\n", "\\n")
					:gsub("\r", "\\r"))
		end
	elseif t == "number" or t == "boolean" then
		return "["..tostring(k).."]"
	else
		return nil, "unsupported key type: "..t
	end
end

local function reprval(v, seen)
	local t = type(v)
	if t == "nil" or t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return (("%q"):format(v)
				:gsub("\\\n", "\\n")
				:gsub("\r", "\\r"))
	elseif t == "table" then
		return reprtable(v, seen)
	else
		return nil, "unsupported value type: "..t
	end
end

--local
function reprtable(t, seen)
	if seen[t] then
		return nil, "circular reference"
	end
	seen[t] = true

	local mt = getmetatable(t)
	if mt and mt.__minser then
		local ok, err = mt.__minser(t, seen)
		seen[t] = nil
		return ok, err
	end

	local out, nc = { }, false

	-- Serialize array part if possible.
	local touched = { }
	for i = 1, math.huge do
		local v = t[i]
		if v == nil then
			break
		end
		touched[i] = true
		local err
		v, err = reprval(v, seen)
		if not v then
			return nil, err
		end
		out[#out+1] = (nc and "," or "")..v
		nc = true
	end

	for k, v in pairs(t) do
		-- Only serialize keys not part of the "array".
		if not touched[k] then
			local err
			k, err = reprkey(k)
			if not k then
				return nil, err
			end
			v, err = reprval(v, seen)
			if not v then
				return nil, err
			end
			out[#out+1] = (nc and "," or "")..k.."="..v
			nc = true
		end
	end

	seen[t] = nil
	return "{"..table.concat(out).."}"
end

---
-- Serialize values.
--
-- @tparam string|number|boolean|table ... Values to serialize.
-- @treturn string Serialized data on success, nil on error.
-- @treturn ?string Error message.
function kminser.dump(...)
	local n, t = select("#", ...), { ... }
	for i = 1, n do
		local v, err = reprval(t[i], { })
		if not v then
			return nil, err
		end
		t[i] = v
	end
	return table.concat(t, ",")
end

---
-- Serialize a single value.
--
-- @tparam string|number|boolean|table val
--  Value to serialize.
-- @tparam ?table seen
--  Cache of seen tables.
-- @treturn string
--  Serialized data on success, nil on error.
-- @treturn ?string
--  Error message.
function kminser.repr(val, seen)
	return reprval(val, seen or { })
end

---
-- Load serialized data.
--
-- @tparam string data Serialized data.
-- @tparam table env Environment for loaded chunk.
-- @treturn number|nil Number of returned values on success, nil on error.
-- @treturn any|string First value on success, error message on error.
-- @treturn any Extra values are returned as extra results.
function kminser.load(data, env)
	local func, err = loadstring("return "..data)
	if not func then
		return nil, err
	end
	setfenv(func, env or { })
	-- Avoid triggering "strict" modules.
	local debug = rawget(_G, "debug")
	local jit = rawget(_G, "jit")
	if jit then
		jit.off(func, true)
	end
	local timedout
	local function timeout()
		timedout = true
		error("timeout")
	end
	local oldhook, oldmask, oldcount
	if debug and debug.gethook then
		oldhook, oldmask, oldcount = debug.gethook()
	end
	local function bail(ok, ...)
		if debug and debug.sethook then
			debug.sethook(oldhook, oldmask, oldcount)
		end
		if timedout then
			return nil, "timeout"
		end
		return ok and select("#", ...) or nil, ...
	end
	if debug and debug.sethook then
		debug.sethook(timeout, "", 10000)
	end
	return bail(pcall(func))
end

return kminser
