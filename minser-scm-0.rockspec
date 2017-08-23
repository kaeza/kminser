
package = "minser"
version = "scm-0"

source = {
   url = "http://github.com/kaeza/lua-minser/archive/master.tar.gz",
}

description = {
	-- TODO: description
	summary = "Data serialization with minification.",
	detailed = [[
		This module contains functions to serialize values to strings, and
		deserialize these strings back to values. It is able to serialize
		strings, numbers, booleans, nil values, and tables.
	]],
	homepage = "http://github.com/kaeza/lua-minser",
	license = "MIT",
}

dependencies = {
   "lua >= 5.1, < 5.4",
}

build = {
	type = "builtin",
	modules = {
		["minser"] = "minser.lua",
	},
}
