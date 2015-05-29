--[[
	FS overwrite
	Author: Wassil JAnssen a.k.a. Creator
]]--

--Variables
local oldFS = fs

--Functions
function fs.isReadOnly(path)
	path = fsh.resolveLinks(path)
	return oldFS.isReadOnly(path)
end

function fs.list(path)
	path = fsh.resolveLinks(path)
	return oldFS.list(path)
end

function fs.exists(path)
	path = fsh.resolveLinks(path)
	return oldFS.exists(path)
end

function fs.isDir(path)
	path = fsh.resolveLinks(path)
	return oldFS.isDir(path)
end

function fs.getDrive(path)
	path = fsh.resolveLinks(path)
	return oldFS.getDrive(path)
end

function fs.getSize(path)
	path = fsh.resolveLinks(path)
	return oldFS.getSize(path)
end

function fs.getFreeSpace(path)
	path = fsh.resolveLinks(path)
	return oldFS.getFreeSpace(path)
end

function fs.makeDir(path)
	path = fsh.resolveLinks(path)
	return oldFS.makeDir(path)
end

function fs.copy(path1,path2)
	path1 = fsh.resolveLinks(path1)
	path2 = fsh.resolveLinks(path2)
	return oldFS.copy(path1,path2)
end

function fs.move(path1,path2)
	path1 = fsh.resolveLinks(path1)
	path2 = fsh.resolveLinks(path2)
	return oldFS.move(path1,path2)
end

function fs.delete(path)
	path = fsh.resolveLinks(path)
	return oldFS.delete(path)
end

function fs.open(path,mode)
	path = fsh.resolveLinks(path)
	return oldFS.open(path,mode)
end

function fs.getMount(path)
	return fsh.resolveLinks(path)
end

function fs.mount(dst,src)
	fsh.mount(dst,src)
end
