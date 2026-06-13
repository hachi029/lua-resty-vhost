local vhost = require("resty.vhost")
describe("router",function()
    local my_vhost
    it("new",function()
        my_vhost = vhost.new(100, 200)
        assert.is_not_nil(vhost)
    end)

    it("insert",function()
        local res, err
        res,err = my_vhost:insert("mail.local.example.cn", 1)
        assert.is_true(res)
        res,err = my_vhost:insert("mail.local.example.cn", 1)
        assert.is_false(res)
        assert.is_not_nil(err)

        res,err = my_vhost:insert(".local.example.cn", 2)
        assert.is_true(res)
        assert.is_nil(err)
        res,err = my_vhost:insert("*.local.example.cn", 2)
        assert.is_false(res)
        assert.is_not_nil(err)  -- "key exists"

        res,err = my_vhost:insert("www.local.example.*", 3)
        assert.is_true(res)
        assert.is_nil(err)
        res,err = my_vhost:insert("www.local.example.", 3)
        assert.is_false(res)
        assert.is_not_nil(err)  -- "key exists"

        res,err = my_vhost:insert("www.local.", 4)
        assert.is_true(res)
        assert.is_nil(err)
        res,err = my_vhost:insert("www.local.*", 4)
        assert.is_false(res)
        assert.is_not_nil(err)  -- "key exists"


        res,err = my_vhost:insert([[~www\.\d{3}\.example.cn]], 5)
        assert.is_true(res)
        assert.is_nil(err)
        res,err = my_vhost:insert([[~www\.\d{3}\.example.cn$]], 5)
        assert.is_false(res)
        assert.is_not_nil(err)  -- "key exists"
        res,err = my_vhost:insert([[~^www\.\d{3}\.example.cn]], 5)
        assert.is_false(res)
        assert.is_not_nil(err)  -- "key exists"
        local res,err = my_vhost:insert([[~^mail\.[a-z]{3,5}\.example.cn]], 6)
        assert.is_true(res)
        assert.is_nil(err)
        local res,err = my_vhost:insert([[~^www\.[a-z]{3,5}\.example.cn]], 7)
        assert.is_true(res)
        assert.is_nil(err)
    end)

    it("lookup",function()
        local match, err = my_vhost:lookup(nil)
        assert.is_nil(match)
        assert.is_not_nil(err)

        match, err = my_vhost:lookup("www.1234.example.com")
        assert.is_nil(match)

        match, err = my_vhost:lookup("www.prd.example.cn")
        assert.is_true(match == 7)

        match, err = my_vhost:lookup("mail.prd.example.cn")
        assert.is_true(match == 6)

        match, err = my_vhost:lookup("www.123.example.cn")
        assert.is_true(match == 5)


        match, err = my_vhost:lookup("www.local.test.cn")
        assert.is_true(match == 4)

        match, err = my_vhost:lookup("www.local.example.com")
        assert.is_true(match == 3)

        match, err = my_vhost:lookup("www.local.example.cn")
        assert.is_true(match == 2)

        match, err = my_vhost:lookup("mail.local.example.cn")
        assert.is_true(match == 1)

        match, err = my_vhost:lookup("www.testtest.example.cn")
        assert.is_nil(match)
    end)

    it("multi_lookup",function()
        local t = {}
        local t1 = my_vhost:multi_lookup("mail.local.example.cn", t)
        assert.is_true(t == t1)
        assert.is_true(#t == 3)
        assert.is_true(t[1] == 1)
        assert.is_true(t[2] == 2)
        assert.is_true(t[3] == 6)

        local t2 = my_vhost:multi_lookup("www.local.example.cn")
        assert.is_false(t == t2)
        assert.is_true(#t2 == 4)
        assert.is_true(t2[1] == 2)
        assert.is_true(t2[2] == 3)
        assert.is_true(t2[3] == 4)
        assert.is_true(t2[4] == 7)
    end)

    it("lookup dynamic",function()
        local res, err = my_vhost:remove([[~mail\.[a-z]{3,5}\.example.cn]])
        assert.is_true(res)
        assert.is_nil(err)
        local match, err = my_vhost:lookup("mail.prd.example.cn")
        assert.is_nil(match)
        match, err = my_vhost:lookup("mail.local.example.cn")
        assert.is_true(match == 1)

        local t = my_vhost:multi_lookup("mail.local.example.cn")
        assert.is_true(#t == 2)
        assert.is_true(t[1] == 1)
        assert.is_true(t[2] == 2)


        res, err = my_vhost:remove("mail.local.example.cn")
        assert.is_true(res)
        assert.is_nil(err)
        match, err = my_vhost:lookup("mail.local.example.cn")
        assert.is_true(match == 2)
        t = my_vhost:multi_lookup("mail.local.example.cn")
        assert.is_true(#t == 1)
        assert.is_true(t[1] == 2)

        res, err = my_vhost:remove(".local.example.cn", 2)
        assert.is_true(res)
        assert.is_nil(err)
        match, err = my_vhost:lookup("mail.local.example.cn")
        assert.is_nil(match)
        t = my_vhost:multi_lookup("mail.local.example.cn")
        assert.is_true(#t == 0)

        match, err = my_vhost:lookup("www.local.example.cn")
        assert.is_true(match == 3)
        t = my_vhost:multi_lookup("www.local.example.cn")
        assert.is_true(#t == 3)
        assert.is_true(t[1] == 3)
        assert.is_true(t[2] == 4)
        assert.is_true(t[3] == 7)

        res, err = my_vhost:remove("www.local.example.*")
        assert.is_true(res)
        assert.is_nil(err)
        match, err = my_vhost:lookup("www.local.example.cn")
        assert.is_true(match == 4)
        t = my_vhost:multi_lookup("www.local.example.cn")
        assert.is_true(#t == 2)
        assert.is_true(t[1] == 4)
        assert.is_true(t[2] == 7)

        res, err = my_vhost:remove("www.local.*")
        assert.is_true(res)
        assert.is_nil(err)
        match, err = my_vhost:lookup("www.local.example.cn")
        assert.is_true(match == 7)
        t = my_vhost:multi_lookup("www.local.example.cn")
        assert.is_true(#t == 1)
        assert.is_true(t[1] == 7)
    end)
end)