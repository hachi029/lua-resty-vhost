use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * 18;

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

no_long_string();
run_tests();

__DATA__

=== TEST 1: Invalid prefix key format
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("invalid*", "should fail")
            ngx.say(ok)
            ngx.say(err or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
false
wildcards must be on label boundary

=== TEST 2: Invalid suffix key format
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("*invalid", "should fail")
            ngx.say(ok)
            ngx.say(err or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
false
wildcards must be on label boundary

=== TEST 3: Duplicate key insertion
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok1, err1 = my_vhost:insert("example.com", "first")
            local ok2, err2 = my_vhost:insert("example.com", "second")
            ngx.say(ok1)
            ngx.say(err1 or "nil")
            ngx.say(ok2)
            ngx.say(err2 or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
true
nil
false
key exists

=== TEST 4: Remove non-existent key
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:remove("nonexistent.com")
            ngx.say(ok)
            ngx.say(err or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
false
key not exists

=== TEST 5: Lookup with invalid input
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local val1, err1 = my_vhost:lookup(nil)
            local val2, err2 = my_vhost:lookup(123)
            ngx.say(val1 or "nil")
            ngx.say(err1 or "nil")
            ngx.say(val2 or "nil")
            ngx.say(err2 or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
nil
invalid key
nil
invalid key

=== TEST 6: Insert with invalid key
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok1, err1 = my_vhost:insert(nil, "value")
            local ok2, err2 = my_vhost:insert(123, "value")
            ngx.say(ok1)
            ngx.say(err1 or "nil")
            ngx.say(ok2)
            ngx.say(err2 or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
nil
invalid key
nil
invalid key
