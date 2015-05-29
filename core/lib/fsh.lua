--[[
	VFS helper and moumting manager
	Author: Wassil Janssen a.k.a. Creator
]]--

--Variables
local mounts = {}
local Internal = {}

--Functions
function Internal.getFirstElement(path)
	return path:sub(1,path:find("/") and path:find("/")-1 or -1)
end

function Internal.makeTable(path,tabl)
	if type(path) ~= "string" then error("Expected string, got "..type(path).."!",2) end
	if type(tabl) ~= "table" then error("Expected table, got "..type(path).."!",2) end
	path = fs.combine("",path)
	local first = Internal.getFirstElement(path)
	--print(first)
	if first == path then
		return tabl, first
	else
		if not tabl[first] then tabl[first] = {} end
		return Internal.makeTable(path:sub(path:find("/")+1,-1),tabl[first])
	end
end

function fsh.mount(destination,source)
	if not fs.exists(destination) then fs.makeDir(destination) end
	if not fs.exists(source) then fs.makeDir(source) end
	local tabl, dir = Internal.makeTable(destination,mounts)
	print(tabl)
	print(dir)
	tabl[dir] = source
end

function Internal.resolveLinks(path,tabl)
	local first = Internal.getFirstElement(path)
	if tabl[first] then
		if type(tabl[first]) == "table" then
			return Internal.resolveLinks(path:sub(path:find("/")+1,-1),tabl[first],start)
		elseif type(tabl[first]) == "string" then
			return tabl[first].."/"..path:sub(path:find("/")+1,-1)
		end
	end
	print(first)
	return false
end

function fsh.resolveLinks(path)
	resolved = Internal.resolveLinks(path,mounts)
	if resolved == false then
		return path
	else
		return fsh.resolveLinks(resolved)
	end
end

return fsh
