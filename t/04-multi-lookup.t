use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * 30;

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

no_long_string();
run_tests();

__DATA__

=== TEST 1: Basic prefix matching
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("www.", "www prefix")
            local val = my_vhost:lookup("www.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
www prefix

=== TEST 2: Basic regex matching
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("~^www\\.[a-z]+\\.example\\.com$", "www regex")
            local val = my_vhost:lookup("www.test.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
www regex

=== TEST 3: Exact match priority
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("exact.com", "exact match")
            local ok, err = my_vhost:insert(".com", "suffix match")
            local val = my_vhost:lookup("exact.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
exact match

=== TEST 4: Multi lookup basic functionality
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)

            -- Insert matches of different types
            local ok, err = my_vhost:insert("exact.com", "exact match")
            local ok, err = my_vhost:insert(".com", "suffix match")

            local results = my_vhost:multi_lookup("exact.com")
            ngx.say(#results)
            ngx.say(results[1])
            ngx.say(results[2] or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
2
exact match
suffix match

=== TEST 5: Multi lookup with no matches
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)

            local results = my_vhost:multi_lookup("nonexistent.com")
            ngx.say(#results)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
0

=== TEST 6: Multi lookup reusing table
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)

            local ok, err = my_vhost:insert("exact.com", "exact match")
            local ok, err = my_vhost:insert(".com", "suffix match")

            local tbl = {}
            tbl.test_field = "existing"

            local results = my_vhost:multi_lookup("exact.com", tbl)

            ngx.say(results == tbl)
            ngx.say(tbl.test_field)
            ngx.say(#results)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
true
existing
2

=== TEST 7: Empty table behavior
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)

            local results = my_vhost:multi_lookup("test.com")
            ngx.say(type(results))
            ngx.say(#results)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
table
0

=== TEST 8: Regex matching with multiple patterns
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)

            local ok, err = my_vhost:insert("~^www\\.[a-z]+\\.com$", "www regex")
            local ok, err = my_vhost:insert("~^api\\-[0-9]+\\.com$", "api regex")

            local val1 = my_vhost:lookup("www.test.com")
            local val2 = my_vhost:lookup("api-123.com")
            ngx.say(val1)
            ngx.say(val2)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
www regex
api regex

=== TEST 9: Prefix and suffix combined
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)

            local ok, err = my_vhost:insert("www.", "www prefix")
            local ok, err = my_vhost:insert(".example.com", "example suffix")

            local val1 = my_vhost:lookup("www.test.com")
            local val2 = my_vhost:lookup("test.example.com")
            ngx.say(val1 or "nil")
            ngx.say(val2 or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
www prefix
example suffix

=== TEST 10: Complex priority test
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)

            -- Insert in different orders to test priority
            local ok, err = my_vhost:insert("~^test\\.[a-z]+\\.com$", "regex match")
            local ok, err = my_vhost:insert("test.", "prefix match")
            local ok, err = my_vhost:insert(".test.com", "suffix match")
            local ok, err = my_vhost:insert("exact.test.com", "exact match")

            local val = my_vhost:lookup("exact.test.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
exact match
