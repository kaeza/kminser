
# lua-minser – Data serialization with minification.

This module contains functions to serialize values to strings, and
deserialize these strings back to values. It is able to serialize
strings, numbers, booleans, nil values, and tables.

The serialized output is a chunk of Lua code yielding comparable values.

The module does its best to generate the most compact code possible.

See the module file for details.

## License

This module is released under a MIT-like license.
See `LICENSE.md` for details.

## Requirements

* [Lua][lua] 5.1 or above.

[lua]: http://lua.org
