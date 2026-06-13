# lua-resty-vhost

Library for matching hostnames to values.

Supports wildcard, `.hostname.tld` or `www.hostname.` and regex in the same way as Nginx's [server_name](http://nginx.org/en/docs/http/ngx_http_core_module.html#server_name) directive.

Keys beginning with `.` or `*.` will match apex and all sub-domains, longest match wins. Non-wildcard matches always win. 
Keys ending with `.` or `*` will match all hosts with that prefix. 
Supports regex matches with `~regex` syntax as well.


## Features

- Exact match: `example.com`
- Wildcard suffix match: `*.example.com` or `.example.com` 
- Wildcard prefix match: `www.example.*` or `www.example.`
- Regex match: `~^[a-z]+\.example\.com$`
- Longest match wins for wildcard patterns
- Support for removing entries
- Support for retrieving multiple matches

## Overview

```
lua_package_path "/path/to/lua-resty-vhost/lib/?.lua;;";

init_by_lua_block {
    local vhost = require("resty.vhost")
    my_vhost = vhost:new()
    local ok, err = my_vhost:insert("example.com",      { key = "example.com.key",          cert = "example.com.crt" })
    local ok, err = my_vhost:insert("www.example.com",  { key = "example.com.key",          cert = "example.com.crt" })
    local ok, err = my_vhost:insert(".sub.example.com", { key = "star.sub.example.com.key", cert = "star.sub.example.com.crt" })
    local ok, err = my_vhost:insert("www.example2.com", { key = "www.example2.com.key",     cert = "www.example2.com.crt" })
    local ok, err = my_vhost:insert("~^[a-z]+\\.api\\.example\\.com$", { key = "api.key",   cert = "api.crt" })
    local ok, err = my_vhost:insert("blog.example.",    { key = "blog.key",                 cert = "blog.crt" })
}

server {
    listen 80 default_server;
    listen 443 ssl default_server;
    server_name vhost;

    ssl_certificate         /path/to/default/cert.crt;
    ssl_certificate_key     /path/to/default/key.crt;

    ssl_certificate_by_lua_block {
        local val, err = my_vhost:lookup(require("ngx.ssl").server_name())
        if not val then
            ngx.log(ngx.ERR, err)
        else
            ngx.log(ngx.DEBUG, "Match, setting certs: ", val.cert, " ", val.key)
            -- set_certs_somehow(val)
        end
    }

    location / {
        content_by_lua_block {
            local val, err = my_vhost:lookup(ngx.var.host)
            if val then
                -- do something based on val
                ngx.say("Matched: ", val.cert)
            else
                if err then
                    ngx.log(ngx.ERR, err)
                end
                ngx.exit(404)
            end
        }
    }
}
```

## Methods

### new
`syntax: my_vhost, err = vhost:new(size?)`

Creates a new instance of resty-vhost with an optional initial size

### insert
`syntax: ok, err = my_vhost:insert(key, value)`

Adds a new hostname key with associated value.

Keys can be:
- String: `example.com` (exact match)
- String starting with `.` or `*.`: `.example.com` (matches example.com and all subdomains)
- String ending with `.` or `*`: `example.` (matches all hosts with example prefix)
- String starting with `~`: `~[regex]` (regex match, will be converted to full match `^[regex]$`)

Returns false and an error message on failure.

### lookup
`syntax: val, err = my_vhost:lookup(hostname)`

Retrieves value for best matching hostname entry.

Priority order: exact match > longest suffix match > longest prefix match > regex match

Returns nil and an error message on failure

### remove
`syntax: ok, err = my_vhost:remove(key)`

Removes a hostname key from the vhost instance.

Returns false and an error message on failure.

### multi_lookup
`syntax: tbl, err = my_vhost:multi_lookup(hostname, [table?])`

Retrieves all matching values for a hostname entry and returns them in a table.

Priority order: exact match > suffix matches > prefix matches > regex matches

If provided, uses the given table for results, otherwise creates a new one.

Returns a table containing all matched values, or nil and an error message on failure.

### map_direct
`syntax: val = my_vhost:map_direct([key])`

Directly access the internal map storage.
If no key is provided, returns the entire map.
If a key is provided, returns the value associated with that key.

## Match Priority

The matching follows this priority order:

1. Exact match: `example.com` matches `example.com`
2. Longest suffix match: `sub.example.com` wins over `.example.com` when looking up `sub.example.com`
3. Longest prefix match: `www.example.com` wins over `www.example.` when looking up `www.example.com` 
4. Regex match: `~[regex]` (applied last)

## Patterns

- `example.com` - exact match only
- `.example.com` or `*.example.com` - matches `example.com` and all subdomains like `www.example.com`, `api.example.com`
- `example.` or `example.*` - matches `example.` prefix like `example.com`, `example.net` 
- `~www\\.[a-z]+\\.example\\.com` - regex match (automatically wrapped with ^ and $)

## TODO
* Trie compression