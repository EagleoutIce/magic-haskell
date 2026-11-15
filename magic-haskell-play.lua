-- magic-haskell-play.lua
-- The link of the play button of an mhsfile: Compiler Explorer opened in a given state
-- (https://godbolt.org/clientstate/<base64 of the state>, see docs/API.md of compiler-explorer),
-- with the program in an editor and an executor that compiles and runs it.

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64(s)
  return ((s:gsub('.', function(c)
    local bits, byte = '', c:byte()
    for i = 8, 1, -1 do bits = bits .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and '1' or '0') end
    return bits
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then return '' end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
    return b64chars:sub(c + 1, c + 1)
  end) .. ({ '', '==', '=' })[#s % 3 + 1])
end

local function json_string(s)
  s = s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' elseif c == '\\' then return '\\\\'
    elseif c == '\n' then return '\\n' elseif c == '\t' then return '\\t' end
    return string.format('\\u%04x', c:byte())
  end)
  return '"' .. s .. '"'
end

-- the url for the program in file, run with the compiler (an id of Compiler Explorer, e.g. ghc9122)
function mhs_play_url(file, compiler, base)
  -- TeX wrote the file into the output directory, if there is one
  local f = io.open(file, 'r')
  if not f and status.output_directory then f = io.open(status.output_directory .. '/' .. file, 'r') end
  if not f then texio.write_nl('magic-haskell: no program for the play button in ' .. file) return '' end
  local source = f:read('a'):gsub('%s+$', '') .. '\n'
  f:close()
  local state = '{"sessions":[{"id":1,"language":"haskell","source":' .. json_string(source)
    .. ',"compilers":[],"executors":[{"compiler":{"id":' .. json_string(compiler)
    .. ',"libs":[],"options":""},"arguments":"","stdin":"","compilerOutputVisible":true}]}]}'
  -- '+', '/', and '=' are escaped, so the state survives every reader of the url
  local encoded = base64(state):gsub('[+/=]', function(c) return string.format('%%%02X', c:byte()) end)
  return base .. encoded
end

-- defines the macro (name without backslash) as the url, in characters of category other
function mhs_play_define(name, file, compiler, base)
  -- in the catcode table of strings, so that the '%' of the escapes stay characters
  local cct = luatexbase and luatexbase.registernumber and luatexbase.registernumber('catcodetable@string')
  if cct then token.set_macro(cct, name, mhs_play_url(file, compiler, base), 'global')
  else token.set_macro(name, mhs_play_url(file, compiler, base), 'global') end
end

-- replaces the file target by the file fresh (both in the output directory, if there is one) if their
-- contents differ, by a rename: several runs at once (one per variant of a document) then never see a half
-- written file, and an unchanged file keeps its time stamp
function mhs_replace(fresh, target)
  -- TeX writes both into the output directory, if there is one
  local dir = status.output_directory
  local h = dir and io.open(dir .. '/' .. fresh, 'rb')
  if h then h:close() fresh, target = dir .. '/' .. fresh, dir .. '/' .. target end
  local function read(f) local g = io.open(f, 'rb') if not g then return nil end local c = g:read('a') g:close() return c end
  if read(fresh) == read(target) then os.remove(fresh) return end
  if not os.rename(fresh, target) then texio.write_nl('magic-haskell: could not write ' .. target) end
end
