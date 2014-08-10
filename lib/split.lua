local stream = require('stream')

local Split = stream.Transform:extend()
function Split:initialize(options)
  options = options or {}

  stream.Transform.initialize(self, options)

  self.buff = ''
  self.sep = options.separator or '\n'

  -- By default Split stream emits chunks directly. User can provide a mapper
  -- function that serves a purpose similar to a Transform stream. If the
  -- mapper emits objects rather than strings, options.objectMode needs to be
  -- set true.
  self.mapper = options.mapper or function(data) return data end
end

function Split:_transform(data, encoding, callback)
  self.buff = self.buff .. data
  local p = self.buff:find(self.sep)
  while p do
    local to_push = self.mapper(self.buff:sub(1, p - 1))
    if to_push then
      self:push(to_push)
    end
    self.buff = self.buff:sub(p + #self.sep, -1)
    p = self.buff:find(self.sep)
  end
  callback()
end

return Split
