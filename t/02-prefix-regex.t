use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * 27;

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

no_long_string();
run_tests();

__DATA__

=== TEST 1: Prefix matching basic test
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("www.example.", "prefix match")
            local val = my_vhost:lookup("www.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
prefix match

=== TEST 2: Prefix matching with different domains
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("api.", "api prefix")
            local val1 = my_vhost:lookup("api.service1.com")
            local val2 = my_vhost:lookup("api.service2.net")
            ngx.say(val1)
            ngx.say(val2)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
api prefix
api prefix

=== TEST 3: Prefix matching priority over regex
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("test.", "prefix match")
            local ok, err = my_vhost:insert("~^test\\.[a-z]+\\.com$", "regex match")
            local val = my_vhost:lookup("test.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
prefix match

=== TEST 4: Regex matching basic test
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("~^www\\.[a-z]+\\.example\\.com$", "regex www.*.example.com")
            local val = my_vhost:lookup("www.test.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
regex www.*.example.com

=== TEST 5: Regex matching with numbers
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("~^api\\-[0-9]+\\.service\\..*$", "regex api-*.service.*")
            local val = my_vhost:lookup("api-123.service.company.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
regex api-*.service.*

=== TEST 6: Regex not matching incorrect format
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("~^www\\.[a-z]+\\.example\\.com$", "regex match")
            local val1 = my_vhost:lookup("www123.test.example.com")  -- No dot between www and test
            local val2 = my_vhost:lookup("www.test.example.org")    -- Different TLD than regex
            ngx.say(val1 or "nil")
            ngx.say(val2 or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
nil
nil

=== TEST 7: Prefix removal test
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("test.", "prefix test")
            local val1 = my_vhost:lookup("test.domain.com")

            local ok, err = my_vhost:remove("test.")
            local val2 = my_vhost:lookup("test.domain.com")

            ngx.say(val1)
            ngx.say(val2 or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
prefix test
nil

=== TEST 8: Regex removal test
--- http_config eval
"$::HttpConfig"
. q{
}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost = vhost:new(10)
            local ok, err = my_vhost:insert("~^temp\\-[a-z]+$", "regex temp")
            local val1 = my_vhost:lookup("temp-abc")

            local ok, err = my_vhost:remove("~^temp\\-[a-z]+$")
            local val2 = my_vhost:lookup("temp-abc")

            ngx.say(val1)
            ngx.say(val2 or "nil")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
regex temp
nil

=== TEST 9: Mixed matching with proper priorities
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
            local ok, err = my_vhost:insert("~^regex\\-[0-9]+\\.test$", "regex match")
            local ok, err = my_vhost:insert("prefix.", "prefix match")
            local ok, err = my_vhost:insert(".suffix.example.com", "suffix match")
            local ok, err = my_vhost:insert("exact.example.com", "exact match")

            -- Test exact match (highest priority)
            local val1 = my_vhost:lookup("exact.example.com")

            -- Test suffix match (second priority)
            local val2 = my_vhost:lookup("sub.suffix.example.com")

            -- Test prefix match (third priority)
            local val3 = my_vhost:lookup("prefix.anything.com")

            -- Test regex match (lowest priority)
            local val4 = my_vhost:lookup("regex-123.test")
            ngx.say(val1)
            ngx.say(val2)
            ngx.say(val3)
            ngx.say(val4)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
exact match
suffix match
prefix match
regex match
