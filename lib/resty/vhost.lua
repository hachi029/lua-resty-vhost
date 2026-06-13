local next = next
local pairs = pairs
local type = type
local str_sub = string.sub
local str_find = string.find
local str_rev = string.reverse
local tbl_insert = table.insert
local tbl_concat = table.concat
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO
local re_find = ngx.re.find

local TYPE_REGEX = "regex"
local TYPE_EXACT = "exact"
local TYPE_SUFFIX = "suffix"
local TYPE_PREFIX = "prefix"


local ok, tab_new = pcall(require, "table.new")
if not ok then
    tab_new = function (narr, nrec) return {} end
end

local _M = {
    _VERSION = "0.02",
}
local mt = { __index = _M }

local DEBUG = false
function _M._debug(debug)
    DEBUG = debug
end

function _M.new(_, size)
    size = size or 10
    local self = {
        suffix_trie = tab_new(0, size),
        prefix_trie = tab_new(0, size),
        map = tab_new(0, size),
        regex = tab_new(0, size)
    }

    return setmetatable(self, mt)
end

-- Splits domain name by . and adds to nested tables
local function trie_insert(trie, key, val)
    -- key: moc.elpmaxe.|elpmaxe.
    if DEBUG then ngx_log(ngx_DEBUG, "Insert: '", key, "'") end
    local pos = str_find(key, ".", 0, true)
    pos = pos or 0
    -- first: moc|elpmaxe
    local first = str_sub(key, 0, pos-1)
    trie[first] = trie[first] or {}
    key = str_sub(key, pos+1)
    if key ~= "" then
        -- trie_insert(trie["moc"], "elpmaxe.")
        trie_insert(trie[first], key, val)
    else
        -- end
        trie[first]["__val"] = val
    end

end

local function trie_remove(trie, key)
    if DEBUG then ngx_log(ngx_DEBUG, "Remove: '", key, "'") end
    local pos = str_find(key, ".", 0, true)
    pos = pos or 0
    local first = str_sub(key, 0, pos-1)
    if trie[first] then
        key = str_sub(key, pos+1)
        if key == "" then
            -- Delete the node if it's the end of the key
            trie[first]["__val"] = nil
        else
            trie_remove(trie[first], key)
        end
    end
    -- clear if is empty
    if not next(trie[first]) then
        trie[first] = nil
    end
end

local function parse_key(key)
    if not key or type(key) ~= "string" then
        return nil, "invalid key"
    end
    local type = TYPE_EXACT

    local prefix = str_sub(key, 1, 1)
    local suffix = str_sub(key, -1)
    if prefix == '*' or prefix == '.' then           -- "*.example.com" is equivalent to ".example.com"
        if prefix == '*' then
            key = str_sub(key, 2, -1)
        end
        prefix = str_sub(key, 1, 1)
        if prefix ~= "." then
            return false, "wildcards must be on label boundary"
        end
        type = TYPE_SUFFIX
    elseif prefix == '~' then       -- regex match: support ~regex
        key = str_sub(key, 2, -1)
        -- convert to full match
        if str_sub(key, 1, 1) ~= "^" then
            key = "^" .. key
        end
        if str_sub(key, -1) ~= "$" then
            key = key .. "$"
        end
        type = TYPE_REGEX
    elseif (suffix == "*" or suffix == ".") then    -- "www.example.*" is equivalent to "www.example."
        if suffix == "*" then
            key = str_sub(key, 1, -2)
            suffix =  str_sub(key, -1)
        end
        if suffix ~= "." then
            return false, "wildcards must be on label boundary"
        end
        type = TYPE_PREFIX
    end
    return type, key
end

function _M.insert(self, key, val)
    local type, key = parse_key(key)
    if not type then
        return type, key
    end

    -- Cannot have duplicate entries
    local map = self.map
    if map[key] then
        return false, "key exists"
    end

    -- 1.Add to basic map
    map[key] = val

    -- 2.Add reversed string to suffix_trie
    if type == TYPE_SUFFIX then

        trie_insert(self.suffix_trie, str_rev(key), val)
    end

    -- 3.Add to prefix_trie
    if type == TYPE_PREFIX then
        trie_insert(self.prefix_trie, key, val)
    end

    -- 4.Add to regex map
    if type == TYPE_REGEX then
        self.regex[key] = val
    end
    return true
end

function _M.remove(self, key)

    local type, key = parse_key(key)
    if not type then
        return type, key
    end

    -- Make sure exists
    local map = self.map
    if not map[key] then
        return false, "key not exists"
    end

    -- Remove from basic map
    map[key] = nil

    -- Remove from suffix_trie
    if type == TYPE_SUFFIX then
        trie_remove(self.suffix_trie, str_rev(key))
    end

    -- Remove from prefix_trie
    if type == TYPE_PREFIX then
        trie_remove(self.prefix_trie, key)
    end

    -- Remove from regex
    if type == TYPE_REGEX then
        self.regex[key] = nil
    end
    return true
end


local function trie_walk(trie, key, last_matched_val, tbl)  -- key:moc.elpmaxe.ao, elpmaxe.ao
    local pos = str_find(key, ".", 0, true)
    pos = pos or 0
    local first = str_sub(key, 0, pos-1)    -- first:moc| elpmaxe

    if first ~= "" and trie[first] then
        local current = trie[first]["__val"]
        if (tbl and current) then
            tbl_insert(tbl, tbl.__base+1, current)
        end
        if current then
            last_matched_val = current
        end
        if DEBUG then ngx_log(ngx_INFO, "found ", first) end
        return trie_walk(trie[first], str_sub(key, pos+1), last_matched_val, tbl)
    end
    return last_matched_val
end

-- Returns best match: priority: exact match > longest suffix match > longest prefix match > regex match
function _M.lookup(self, key)
    if not key or type(key) ~= "string" then
        return nil, "invalid key"
    end

    -- 1.Attempt to match full string first
    local match = self.map[key]
    if match then
        return match
    end

    -- 2.Search the suffix_trie
    if DEBUG then ngx_log(ngx_DEBUG, "Searching: ", key) end

    local val = trie_walk(self.suffix_trie, str_rev(key), nil)

    if val then
        return val
    end

    -- 3.Search the prefix_trie
    val = trie_walk(self.prefix_trie, key, nil)

    if val then
        return val
    end

    if DEBUG then ngx_log(ngx_DEBUG, "Try regex match") end
    -- 4.Search regex
    for re, val in pairs(self.regex) do
        if re_find(key, re, "ijo") then
            return val
        end
    end
    return nil
end

-- tbl: contains all matched records, priority: exact match > longest suffix match > longest prefix match > regex match
function _M.multi_lookup(self, key, tbl)
    if not key or type(key) ~= "string" then
        return nil, "invalid key"
    end

    if not tbl then
        tbl = tab_new(5, 0)
    end

    -- 1.Attempt to match full string first
    local match = self.map[key]


    if DEBUG then ngx_log(ngx_DEBUG, "Searching: ", key) end

    -- 2.Search suffix_trie, insert matched to tbl
    tbl.__base = #tbl
    trie_walk(self.suffix_trie, str_rev(key), nil, tbl)

    -- 3.Search prefix_trie, insert matched to tbl
    tbl.__base = #tbl
    trie_walk(self.prefix_trie, key, nil, tbl)

    if match then
        tbl_insert(tbl, 1, match)
    end

    if DEBUG then ngx_log(ngx_DEBUG, "Try regex match") end
    -- 4.Search regex
    for re, val in pairs(self.regex) do
        if re_find(key, re, "ijo") then
            tbl_insert(tbl, val)
        end
    end
    return tbl
end

function _M.map_direct(self, key)
    if not key then
        return self.map
    end

    local type, key = parse_key(key)
    if not type then
        return type, key
    end

    return self.map[key]
end

return _M