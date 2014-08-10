local test = require('tape')('test split')
local stream = require('stream')
local table = require('table')
local timer = require('timer')

local Split = require('../lib/split')

function getSource(src_data)
  local len = #src_data
  local src = stream.Readable:new()
  src._read = function(this, n)
    for i=1,n do
      if 1 <= #src_data then
        local chunk = table.remove(src_data, 1)
        timer.setTimeout(i * 50, function()
          this:push(chunk)
        end)
      else
        timer.setTimeout((len + 1) * 50, function()
          this:push(nil)
        end)
      end
    end
  end

  return src
end

test('incoming chunks are properly merged', nil, function(t)
  local src = getSource({'chunk 1 ', 'chunk 2 ', 'chunk 3\n'})

  local sink_data = {}
  local sink = stream.Writable:new()
  sink._write = function(this, data, encoding, callback)
    table.insert(sink_data, data)
    callback()
  end
  sink:once('finish', function()
    t:equal(#sink_data, 1, 'should only emit 1 chunk since there is only 1 separator in input')
    t:equal(sink_data[1], 'chunk 1 chunk 2 chunk 3', 'emitted wrong merged data')
    t:finish()
  end)

  src:pipe(Split:new()):pipe(sink)
end)

test('chunks are properly split', nil, function(t)
  local src = getSource({'chunk 1 ', 'chunk 2\n', 'line 2\nline 3\n'})

  local sink_data = {}
  local sink = stream.Writable:new()
  sink._write = function(this, data, encoding, callback)
    table.insert(sink_data, data)
    callback()
  end
  sink:once('finish', function()
    t:equal(#sink_data, 3, 'should emit 3 chunks since there are 3 separator in input')
    t:equal(sink_data[1], 'chunk 1 chunk 2', 'emitted wrong data')
    t:equal(sink_data[2], 'line 2', 'emitted wrong data')
    t:equal(sink_data[3], 'line 3', 'emitted wrong data')
    t:finish()
  end)

  src:pipe(Split:new()):pipe(sink)
end)

test('custom multi-bytes separator', nil, function(t)

  -- unicode separator
  local src = getSource({'chunk 1 ', 'chunk 2囧', 'line 2囧line 3囧'})

  local sink_data = {}
  local sink = stream.Writable:new()
  sink._write = function(this, data, encoding, callback)
    table.insert(sink_data, data)
    callback()
  end
  sink:once('finish', function()
    t:equal(#sink_data, 3, 'should emit 3 chunks since there are 3 separator in input')
    t:equal(sink_data[1], 'chunk 1 chunk 2', 'emitted wrong data')
    t:equal(sink_data[2], 'line 2', 'emitted wrong data')
    t:equal(sink_data[3], 'line 3', 'emitted wrong data')
    t:finish()
  end)

  src:pipe(Split:new({separator = '囧'})):pipe(sink)
end)

test('mapper emits objects', nil, function(t)
  local src = getSource({'chunk 1 ', 'chunk 2\n', 'line 2\n'})

  local sink_data = {}
  local sink = stream.Writable:new({objectMode = true})
  sink._write = function(this, data, encoding, callback)
    table.insert(sink_data, data)
    callback()
  end
  sink:once('finish', function()
    t:equal(#sink_data, 2, 'should emit 2 chunks since there are 2 separator in input')
    t:equal(type(sink_data[1]), 'table', 'emitted wrong data type')
    t:equal(type(sink_data[2]), 'table', 'emitted wrong data type')
    t:equal(sink_data[1].data, 'chunk 1 chunk 2', 'emitted wrong data')
    t:equal(sink_data[2].data, 'line 2', 'emitted wrong data')
    t:finish()
  end)

  src:pipe(Split:new({
    objectMode = true,
    mapper = function(data)
      return {
        data = data
      }
    end,})):pipe(sink)
  end)

