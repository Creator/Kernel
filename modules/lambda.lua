local lambda = Class(
  function(self, path)
    self.path = (path and path or "")
  end
)

function lambda:load(file)
  if self.path == "" then
    self.path = file
  end

  if not fs.exists(self.path) then
    error(("File [%s] doesn't exist."):format(self.path))
  end

  local e = fs.open(self.path, 'r')
  if not e then print("File not found: ", self.path) error() end
  local data = textutils.unserialize( base64.decode(  e.readAll()))
  if not data then return end
  e.close()

  local sections = data.sections
  local exec, err = loadstring(base64.decode(data.sections.text))

  self.exec = exec
  self.error = err

  self.sects = sections

  self.runThisFunc = function()
    if self.sects.preload then
      for k, v in pairs(self.sects.preload)
        v()
      end
    end
    self.exec()
  end
  return self
end

function lambda:run(...)
  if not self.exec then
    error("Not loaded.")
  end
  local tEnv = {
    ["_LAMBDA"] = true,
    ["_HELIOS"] = true,
    ["_FILE"]   = self.path
  }
  setmetatable(tEnv, {["__index"] = _G})
  setfenv(self.exec, tEnv)
  if self.sects.preload then
    for k, v in pairs(self.sects.preload) do
      local preload = loadstring(base64.decode(v))
      setfenv(preload, tEnv)
      preload()
    end
  end
  return pcall(self.exec, ...)
end

function lambda.isLambda(file)
  local linstance = lambda:new(file)
  return (
    linstance and
      (linstance.exec and
        type(linstance.exec) == 'function' or false)
      or false
    or false
  )
end

local lambdawrite = Class(
  function(self, path)
    self.path = path
  end
)

function lambdawrite:addPreloadFunction(func)
  if not self.preloads then
    self.preloads = {}
  end

  table.insert(self.preloads, func)
  return self
end

function lambdawrite:linkLambda(obj)
  if not self.preloads then
    self.preloads = {}
  end

  table.insert(self.preloads, obj.exec)
  if obj.preloads then
    for k, v in pairs(obj.preloads) do
      table.insert(self.preloads, v)
    end
  end
end


function lambdawrite:addVar(key, val)
  if not self.preloads then
    self.preloads = {}
  end

  table.insert(self.preloads, function()
    _G[key] = val
  end)
end

function lambdawrite:addMainFunction(func)
  if self.main then
    error("You can only add 1 main function.")
  end

  self.main = func
  return self
end

function lambdawrite:write(file)
  if not self.path and file then
    self.path = file
  end
  local data = {}
  data.sections = {}
  data.sections.text = base64.encode(string.dump(self.main))
  data.sections.head = {
    ["HEAD"] = "Lambda (HELIOS)",
    ["MAGIC"] = 0xbadb00b
  }
  data.sections.preload = {}
  if self.preloads then
    for k, v in pairs(self.preloads) do
      table.insert(data.sections.preload, base64.encode(string.dump(v)))
    end
  end

  local e = fs.open(self.path, 'w')
  for k, v in pairs(tt(base64.encode(textutils.serialize(data)), 50)) do
    e.writeLine(v)
  end
  e.close()
end


modules.module "executable" {
    ["text"] = {
        ["load"] = function()
          _G.Executable = lambda
          _G.ExecutableWriter = lambdawrite
        end,
        ["unload"] = function()
          _G.Executable, _G.ExecutableWriter = nil, nil
        end
     }
}
DefaultEnvironment = {
  ["HELIOS"] = true
}
setmetatable(DefaultEnvironment, {
  ["__index"] = function(t, k)
    return _G[k]
  end
})



local thread = {}

function thread:new( f )

  local t = {}

  t.state = "running"
  t.environment = setmetatable( {}, { __index = getfenv( 2 ) } )

  t.filter = nil

  t.raw_environment = setmetatable( {}, {
    __index = function( _, k )
      return t.environment[k]
    end,
    __newindex = function( _, k, v )
      t.environment[k] = v
    end
  } )

  setfenv( f, t.raw_environment )
  t.func = f
  t.co = coroutine.create( f )

  setmetatable( t, {
    __index = self;
    __type = function( self )
      return self:type()
    end;
  } )

  return t
end

function thread:stop()
  if self.state ~= "dead" then
    self.state = "stopped"
  end
end

function thread:pause()
  if self.state == "running" then
    self.state = "paused"
  end
end

function thread:resume()
  if self.state == "paused" then
    self.state = "running"
  end
end

function thread:restart()
  self.state = "running"
  self.co = coroutine.create( self.func )
end

function thread:update( event, ... )
  if self.state ~= "running" then return true, self.state end -- if not running, don't update
  if self.filter ~= nil and self.filter ~= event then return true, self.filter end -- if filtering an event, don't update
  local ok, data = coroutine.resume( self.co, event, ... )
  if not ok then
    self.state = "stopped"
    return false, data
  end
  if coroutine.status( self.co ) == "dead" then
    self.state = "stopped"
    return true, "die"
  end
  self.filter = data
  return true, data
end

function thread:type()
  return "thread"
end

local process = {}

function process:new( name )
  local p = {}

  p.name = name
  p.children = {}

  setmetatable( p, {
    __index = self;
    __type = function( self )
      return self:type()
    end;
  } )

  return p
end

function process:spawnThread( f )
  local t = thread:new( f )
  table.insert( self.children, 1, t )
  return t
end

function process:spawnSubProcess( name )
  local p = process:new( name )
  table.insert( self.children, 1, p )
  return p
end

function process:spawnSubprocess( name )
  local p = process:new( name )
  table.insert( self.children, 1, p )
  return p
end

function process:update( event, ... )
  for i = #self.children, 1, -1 do
    local ok, data = self.children[i]:update( event, ... )
    if not ok then
      if self.exceptionHandler then
        self:exceptionHandler( self.children[i], data )
      else
        return false, data
      end
    end
    if data == "die" or self.children[i].state == "stopped" then
      self.children[i].state = "dead"
      table.remove( self.children, i )
    end
  end
  return true, #self.children == 0 and "die"
end

function process:stop()
  for i = 1, #self.children do
    self.children[i]:stop()
  end
end

function process:pause()
  for i = 1, #self.children do
    self.children[i]:pause()
  end
end

function process:resume()
  for i = 1, #self.children do
    self.children[i]:resume()
  end
end

function process:restart()
  for i = 1, #self.children do
    self.children[i]:restart()
  end
end

function process:list( deep )
  local t = {}
  for i = #self.children, 1, -1 do
    if self.children[i]:type() == "process" then
      if deep then
        local c = self.children[i]:list( true )
        c.name = self.children[i].name
        t[#t + 1] = c
      else
        t[#t + 1] = self.children[i]
      end
    elseif self.children[i]:type() == "thread" then
      t[#t + 1] = self.children[i]
    end
  end
  return t
end

function process:type()
  return "process"
end

process.main = process:new "main"

local function _doload(id)

  local pid = id:gsub(':', '/')

  if not string.sub(pid, -4) == '.lua' then
    if not fs.exists(pid) then
      pid = pid..'.lua'
    end
  end


  local ret, err = loadfile(pid)
  if not ret then
    error()
  end

  return ret()
end


local _thread = modules.module 'threads' {
  text = {
    load = function()
      _G.process = process
      _G.thread = thread
    end,
    unload = function()
      _G.process, _G.thread = nil, nil
    end
  }
}


local _load = modules.module 'load' {
  text = {
    load = function()
      _G.load = _doload
    end,
    unload = function()
      _G.load = nil
    end
  }
}


local execHandles = {}
_G.ExecutableManager = {}

function ExecutableManager.addHandle(name, isfunc, dofunc)
  execHandles[name] = ({isfunc, dofunc})
end

function ExecutableManager.removeHandle(name)
  execHandles[name] = nil
end

function ExecutableManager.getIfIs(file)
  for k, v in pairs(execHandles) do
      if v[1](file) then return v[2] end
  end
  return false
end

function ExecutableManager.open(file)
  if not fs.exists(file) then
    error("Error.")
  end

  if lambda.isLambda(file) then
    return lambda:new(file):load().runThisFunc
  elseif ExecutableManager.getIfIs(file) then
    return ExecutableManager.getIfIs(file)
  else
    return loadfile(file)
  end
end

function execl(file, ...)
  local fnc = ExecutableManager.load(file)
  local _env = {
    ["_FILE"] = file,
    ["process"] = {
      ["this"] = process.main:spawnSubprocess()
    }
  }
  setmetatable(_env, {["__index"] = function(t, k)
      if not rawget(t, k) then
        return rawget(_G, k)
      else
        return rawget(t, k)
      end
    end
  })

  setfenv(fnc, _env)
  return pcall(fnc, ...)
end

function execv(file, args)
  return execl(file, unpack(args))
end

function execpl(file, env, ...)
  local fnc = ExecutableManager.load(file)
  local _env = {
    ["_FILE"] = file,
    ["process"] = {
      ["this"] = process.main:spawnSubprocess()
    }
  }
  setmetatable(_env, {["__index"] = function(t, k)
      if not rawget(t, k) then
        return rawget(_G, k)
      elseif not rawget(_G, k) then
        return rawget(env, k)
      else
        return rawget(t, k)
      end
    end
  })

  setfenv(fnc, _env)
  return pcall(fnc, ...)
end

function execpv(file, env, argv)
  return execpl(file, env, unpack(argv))
end
