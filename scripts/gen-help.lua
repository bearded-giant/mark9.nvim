-- scripts/gen-help.lua
local infile = "README.md"
local outfile = "doc/mark9.txt"

local input = io.open(infile, "r")
assert(input, "Failed to open README.md")

local output = io.open(outfile, "w")
assert(output, "Failed to open doc/mark9.txt for writing")

output:write("*mark9.txt*  Plugin documentation for mark9.nvim\n\n")

for line in input:lines() do
	line = line:gsub("^#%s+", "") -- # Heading
	line = line:gsub("^##%s+", "") -- ## Subheading
	line = line:gsub("^###%s+", "") -- ### Smaller heading
	line = line:gsub("```.lua", ">") -- Code block start
	line = line:gsub("```", "<") -- Code block end
	output:write(line .. "\n")
end

output:write("\nvim:tw=78:ts=8:ft=help:norl:\n")
input:close()
output:close()
