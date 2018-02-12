require 'minitest/autorun'
require 'netlify_redirector'
require 'mocha/mini_test'
require 'jwt'

class RedirectMatcher
  attr_accessor :conditions, :exceptions, :force404

  def initialize(redirects, options = {})
    @redirects = redirects
    @options = options
  end

  def match(request)
    res = NetlifyRedirector.new.match(@redirects, request, @options[:jwt_secret], @options[:jwt_role_path])
    self.conditions = res[:conditions]
    self.exceptions = res[:exceptions]
    self.force404 = res[:force_404]
    res[:rule][:conditions] = conditions if res[:rule] && conditions
    res[:rule]
  end
end

class TestRedirector < MiniTest::Unit::TestCase
  def test_no_match
    assert_nil RedirectMatcher.new([]).match(stub_everything(:path => "/"))
  end

  def test_simple_match
    redirector = RedirectMatcher.new([{:path => "/home", :to => "/"}])
    assert_equal({:to => "/", :status => 301, :force => true}, redirector.match(stub_everything(:path => "/home")))
    assert_equal({:to => "/", :status => 301, :force => true}, redirector.match(stub_everything(:path => "/home/")))
    assert_nil redirector.match(stub_everything(:path => "/home/s"))
    assert_nil redirector.match(stub_everything(:path => "/homes"))
  end

  def test_carrot_tweeting_match
    redirector = RedirectMatcher.new([{:path=>"/tweeting", :to=>"https://twitter.com/carrot", :status=>301}])
    assert_equal({:to => "https://twitter.com/carrot", :status => 301, :force => true}, redirector.match(stub_everything(:path => "/tweeting")))
  end

  def match_with_placeholder
    redirector = RedirectMatcher.new([{:path => "/products/:id", :to => "/store/:id"}])
    assert_equal({:to => "/store/ipod", :status => 301}, redirector.match(stub_everything(:path => "/products/ipod")))
  end

  def match_on_query_parameter
    redirector = RedirectMatcher.new([{:path => "/products", :params => {:id => ":id"}, :to => "/store/:id"}])
    assert_nil redirector.match(stub_everything(:path => "/products", :params => {}, :query_string => ""))
    assert_equal redirector.conditions, {"Query" => ""}
    redirector = RedirectMatcher.new([{:path => "/products", :params => {:id => ":id"}, :to => "/store/:id"}])
    assert_equal({:to => "/store/ipod", :status => 301, :params => {:id => ":id"}, :force => true, :conditions => {"Query" => "id=ipod"}}, redirector.match(stub_everything(:path => "/products", :params => {"id" => "ipod"}, :query_string => "id=ipod")))
  end

  def test_match_on_splat
    redirector = RedirectMatcher.new([{:path => "/*", :to => "/index.html", :status => 200}])
    assert_equal({:to => "/index.html", :status => 200}, redirector.match(stub_everything(:path => "/r/pics", :params => {"t" => "all"})))

    redirector = RedirectMatcher.new([{:path => "/news/*", :to => "/blog/:splat", :status => 301}])
    assert_equal({:to => "/blog/article", :status => 301}, redirector.match(stub_everything(:path => "/news/article")))
    assert_equal({:to => "/blog/", :status => 301}, redirector.match(stub_everything(:path => "/news")))
  end

  def test_match_on_splat_with_capture
    redirector = RedirectMatcher.new([{:path => "/news/*", :to => "/blog/:splat"}])
    assert_equal({:to => "/blog/this/is/a/post", :status => 301}, redirector.match(stub_everything(:path => "/news/this/is/a/post")))
  end

  def test_match_proxy_rule
    redirector = RedirectMatcher.new([{:path => "/api/*", :to => "https://api.bitballoon.com/:splat", :status => 200}])

    assert_equal({:to => "https://api.bitballoon.com/sites/1234", :status => 200}, redirector.match(stub_everything(:path => "/api/sites/1234")))
  end

  def test_match_with_host_and_scheme
    redirector = RedirectMatcher.new([{:path => "/*", :to => "https://www.bitballoon.com/:splat", :host => "www.bitballoon.com", :scheme => "http"}])

    assert_equal(
      {:to => "https://www.bitballoon.com/hello", :status => 301},
      redirector.match(stub_everything(:path => "/hello", :host => "www.bitballoon.com", :scheme => "http"))
    )

    assert_nil redirector.match(stub_everything(:path => "/hello", :host => "www.bitballoon.com", :scheme => "https"))
  end

  def test_respect_force_instruction
    redirector = RedirectMatcher.new([{:path => "/*", :to => "/index.html", :status => 200, :force => true}])
    assert_equal({:to => "/index.html", :status => 200, :force => true}, redirector.match(stub_everything(:path => "/r/pics", :params => {"t" => "all"})))
  end

  def test_with_country_constraint_but_no_country_header
    redirector = RedirectMatcher.new([{:path => "/", :to => "/china", :status => 302, :conditions => {"Country" => "cn,tw"}}])
    assert_nil redirector.match(stub_everything(:path => "/", :env => {}))
    assert_equal(%w{cn tw}, redirector.exceptions["Country"].split(","))
  end

  def test_with_country_constraint_and_wrong_country_header
    redirector = RedirectMatcher.new([
      {:path => "/", :to => "/china", :status => 302, :conditions => {"Country" => "cn,tw"}},
      {:path => "/", :to => "/india", :status => 302, :conditions => {"Country" => "in"}}
    ])
    assert_nil redirector.match(stub_everything(:path => "/", :env => {"HTTP_X_COUNTRY" => "US"}))
    assert_equal(%w{cn in tw}, redirector.exceptions["Country"].split(",").sort)
  end

  def test_with_country_constraint_and_matching_country
    redirector = RedirectMatcher.new([
      {:path => "/", :to => "/china", :status => 302, :conditions => {"Country" => "cn,tw"}},
      {:path => "/", :to => "/india", :status => 302, :conditions => {"Country" => "in"}}
    ])
    assert_equal({:to => "/china", :status => 302, :force => true, :conditions => {"Country" => "cn,tw"}} ,redirector.match(stub_everything(:path => "/", :env => {"HTTP_X_COUNTRY" => "CN"})))
    assert_equal({:to => "/india", :status => 302, :force => true, :conditions => {"Country" => "in"}} ,redirector.match(stub_everything(:path => "/", :env => {"HTTP_X_COUNTRY" => "IN"})))
  end

  def test_with_language_constraint_and_matching_language
    redirector = RedirectMatcher.new([
      {:path => "/china", :to => "/china/zh", :status => 302, :conditions => {"Language" => "zh"}}
    ])
    assert_equal({:to => "/china/zh", :status => 302, :force => true, :conditions => {"Language" => "zh"}} ,redirector.match(stub_everything(:path => "/china", :env => {"HTTP_X_LANGUAGE" => "zh"})))
    assert_equal({:to => "/china/zh", :status => 302, :force => true, :conditions => {"Language" => "zh"}} ,redirector.match(stub_everything(:path => "/china", :env => {"HTTP_X_LANGUAGE" => "zh-tw"})))

    redirector = RedirectMatcher.new([
      {:path => "/china", :to => "/china/zh", :status => 302, :conditions => {"Language" => "zh-tw"}}
    ])
    assert_nil redirector.match(stub_everything(:path => "/", :env => {"HTTP_X_LANGUAGE" => "zh"}))
    assert_equal({:to => "/china/zh", :status => 302, :force => true, :conditions => {"Language" => "zh-tw"}} ,redirector.match(stub_everything(:path => "/china", :env => {"HTTP_X_LANGUAGE" => "zh-tw"})))
  end

  def test_match_encoded
    invalid = "url=http://www.sculj.cn/ReadNews.asp?NewsID=4257&BigClassName=��������&SmallClassName=120����У��ר��&SpecialID=41"
    redirector = RedirectMatcher.new([{:path => "/", :params => {:url => ":url"}, :to => "/get?url=:url"}])

    resp = redirector.match(stub_everything(:path => "/", :params => {"url" => invalid}, :query_string => "url=#{invalid}"))
    refute_nil resp
  end

  def test_a_language_redirect_to_absolute_path
    redirector = RedirectMatcher.new([
      {:path => "/*", :to => "http://www.example.com/au/:splat", :status => 302, :conditions => {"Country" => "au"}}
    ])

    assert_nil redirector.match(stub_everything(:path => "/", :scheme => "http", :host => "www.example.com", :env => {}))
    assert_equal({:to => "http://www.example.com/au/", :force => true, :status => 302, :conditions => {"Country" => "au"}}, redirector.match(stub_everything(:path => "/", :scheme => "http", :host => "www.example.com", :env => {"HTTP_X_COUNTRY" => "au"})))
    assert_nil redirector.match(stub_everything(:path => "/au", :scheme => "http", :host => "www.example.com", :env => {"HTTP_X_COUNTRY" => "au"}))
  end

  def test_redirect_with_inner_named_match_when_no_page_is_found
    redirector = RedirectMatcher.new([
      {:path => "/:locale/blog", :to => "/:locale/blog/1"}
    ])

    assert_equal({:to => "/de/blog/1", :status => 301}, redirector.match(stub_everything(:path => "/de/blog")))
  end

  def test_redirect_with_query_param
    redirector = RedirectMatcher.new([
      {:path => "/test", :params => {"q"=>":q"}, :to => "https://www.google.com?q=:q"}
    ])

    assert_equal({:to => "https://www.google.com?q=test", :status => 301, :force => true, :conditions => {"Query" => "q=test"}}, redirector.match(stub_everything(:path => "/test", :query_string => "q=test")))
  end

  def test_match_on_query_parameter
    redirector = RedirectMatcher.new([{path: "/products", params: {id: ":id"}, to: "/store/:id"}])
    assert_nil redirector.match(stub_everything(path: "/products", params: {}, query_string: ""))
    assert_equal({"Query" => ""}, redirector.conditions)

    redirector = RedirectMatcher.new([{path: "/products", params: {id: ":id"}, to: "/store/:id"}])
    assert_equal({to: "/store/ipod", status: 301, force: true, conditions: {"Query" => "id=ipod"}}, redirector.match(stub_everything(path: "/products", params: {"id" => "ipod"}, query_string: "id=ipod")))

  end

  def test_redirect_with_query_param_with_a_slash_in_the_value
    redirector = RedirectMatcher.new([
      {:path => "/", :params => {"_escaped_fragment_"=>"/test"}, :to => "https://www.google.com?q=test"}
    ])

    assert_equal({:to => "https://www.google.com?q=test", :status => 301, :force => true, :conditions => {"Query" => "_escaped_fragment_=%2Ftest"}}, redirector.match(stub_everything(:path => "/", :query_string => "_escaped_fragment_=%2Ftest")))
  end

  def test_complex_rules_for_country_and_language_based_redirects
    redirector = RedirectMatcher.new([
      {:path => "/", :to => "/china", :status => 302, :conditions => {"Country" => "cn"}},
      {:path => "/", :to => "/india", :status => 302, :conditions => {"Country" => "in"}},
      {:path => "/china/*", :to => "/china/cn-zh/:splat", :status => 302, :conditions => {"Language" => "zh"}},
      {:path => "/*", :to => "/cn-zh/:splat", :status => 302, :conditions => {"Language" => "zh"}}
    ])

    assert_nil redirector.match(stub_everything(:path => "/", :env => {}))
    assert_equal ["cn", "in"], redirector.exceptions["Country"].split(",").sort
    assert_equal ["zh"], redirector.exceptions["Language"].split(",").sort

    assert_equal(
      {:to => "/china", :status => 302, :force => true, :conditions => {"Country" => "cn"}},
      redirector.match(stub_everything(:path => "/", :env => {"HTTP_X_COUNTRY" => "cn"}))
    )

    assert_equal(
      {:to => "/china", :status => 302, :force => true, :conditions => {"Country" => "cn"}},
      redirector.match(stub_everything(:path => "/", :env => {"HTTP_X_COUNTRY" => "cn", "HTTP_X_LANGUAGE" => "cn"}))
    )

    assert_equal(
      {:to => "/cn-zh/", :status => 302, :force => true, :conditions => {"Language" => "zh"}},
      redirector.match(stub_everything(:path => "/", :env => {"HTTP_X_COUNTRY" => "us", "HTTP_X_LANGUAGE" => "zh"}))
    )

    assert_nil redirector.match(stub_everything(:path => "/china", :env => {"HTTP_X_LANGUAGE" => "en"}))
    assert_equal({"Language" => "zh"}, redirector.exceptions)

    assert_equal(
      {:to => "/china/cn-zh/", :status => 302, :force => true, :conditions => {"Language" => "zh"}},
      redirector.match(stub_everything(:path => "/china", :env => {"HTTP_X_LANGUAGE" => "zh"}))
    )

    assert_nil redirector.match(stub_everything(:path => "/china/cn-zh", :env => {"HTTP_X_LANGUAGE" => "en"}))

    assert_nil redirector.match(stub_everything(:path => "/china/something", :env => {"HTTP_X_LANGUAGE" => "en"}))
    assert_equal({"Language" => "zh"}, redirector.exceptions)

    assert_equal(
      {:to => "/china/cn-zh/something", :force => true, :status => 302, :conditions => {"Language" => "zh"}},
      redirector.match(stub_everything(:path => "/china/something", :env => {"HTTP_X_LANGUAGE" => "zh"}))
    )

    assert_nil redirector.match(stub_everything(:path => "/china/cn-zh/something", :env => {"HTTP_X_LANGUAGE" => "zh"}))
  end

  def test_redirect_with_splat_match_when_no_page_is_found
    redirector = RedirectMatcher.new([{
      :path =>"/news/*",
      :to =>"/blog/:splat",
      :status =>301
    }])

    assert_equal(
      {:to => "/blog/2015/07/23/some-story", :status => 301},
      redirector.match(stub_everything(:path => "/news/2015/07/23/some-story"))
    )
  end

  # def test_redirector_with_invalid_uri
  #   redirector = RedirectMatcher.new([{
  #     :path =>"/api/content/v1/parser",
  #     :to =>"https://aws.readability.com/api/content/v1/parser?url=:url&token=:token",
  #     :params =>{"url"=>":url", "token"=>":token"},
  #     :status =>200,
  #     :proxy =>true
  #   }])

  #   url = "http://www.china-files.com/it/link/49052/a-bollywood-arriva-la-«tassa-patriottica»-voluta-dagli-ultrahindu"

  #   assert_equal(
  #     {:to => "https://aws.readability.com/api/content/v1/parser?url=#{url}&token=token", :status => 200, :proxy => true},
  #     redirector.match(stub_everything(:path => "/api/content/v1/parser", :query_string => "token=token&token=asdfafd&url=http%3A%2F%2Fwww.china-files.com%2Fit%2Flink%2F49052%2Fa-bollywood-arriva-la-%C2%ABtassa-patriottica%C2%BB-voluta-dagli-ultrahindu"))
  #   )
  # end

  def test_redirector_with_roles
      redirector = RedirectMatcher.new([
        {:path => "/admin/*", :to => "/admin/:splat", :status => 200, :conditions => {"Role" => "admin"}}
      ], :jwt_secret => "foobar")

      payload = {"app_metadata" => {"authorization" => {"roles" => ["admin"]}}, "exp" => (Time.now + 600).to_i}
      token = JWT.encode payload, "foobar", 'HS256'

      assert_equal(
        {:to => "/admin/users", :status => 200, :force => true, :conditions => {"JWT" => "app_metadata.authorization.roles:admin"}},
        redirector.match(stub_everything(:path => "/admin/users", :cookies => {"nf_jwt" => token}))
      )
    end


    def test_redirector_with_wildcard_roles
      redirector = RedirectMatcher.new([
        {path: "/membership/", to: "/membership/member", status: 200, conditions: {"Role" => "member"}},
        {path: "/membership/", to: "/membership/smashing", status: 200, conditions: {"Role" => "smashing"}},
        {path: "/membership/", to: "/membership/free", status: 200, conditions: {"Role" => "*"}},
        {path: "/membership/", to: "/membership/", status: 200}
      ], :jwt_secret => "foobar")

      assert_equal(
        {:to=>"/membership/", :status=>200, :force=>true},
        redirector.match(stub_everything(:path => "/membership/", :cookies => {}))
      )

      payload = {"app_metadata" => {"authorization" => {"roles" => ["admin"]}}, "exp" => (Time.now + 600).to_i}
      token = JWT.encode payload, "foobar", 'HS256'

      assert_equal(
        {:to => "/membership/free", :status => 200, :force => true, :conditions => {"JWT" => "app_metadata.authorization.roles:*"}},
        redirector.match(stub_everything(:path => "/membership/", :cookies => {"nf_jwt" => token}))
      )

      payload = {"app_metadata" => {"authorization" => {"roles" => ["smashing"]}}, "exp" => (Time.now + 600).to_i}
      token = JWT.encode payload, "foobar", 'HS256'

      assert_equal(
        {:to => "/membership/smashing", :status => 200, :force => true, :conditions => {"JWT" => "app_metadata.authorization.roles:smashing"}},
        redirector.match(stub_everything(:path => "/membership/", :cookies => {"nf_jwt" => token}))
      )
    end

    def test_redirector_with_roles_falls_back_to_unauthorized
      redirector = RedirectMatcher.new([
        {path: "/admin/*", to: "/admin/:splat", status: 200, conditions: {"Role" => "admin"}},
        {path: "/admin/*", to: "/admin/editor/:splat", status: 200, conditions: {"Role" => "editor"}},
        {path: "/admin/*", to: "/404", status: 404},
      ], :jwt_secret => "foobar")

      m = redirector.match(stub_everything(path: "/admin/users", cookies: {}))
      assert_equal "app_metadata.authorization.roles:admin,editor", redirector.exceptions["JWT"]
    end

    def test_redirector_with_multiple_roles
      redirector = RedirectMatcher.new([
        {:path => "/member/*", :to => "/member/:splat", :status => 200, :conditions => {"Role" => "admin,member"}}
      ], :jwt_secret => "foobar")

      payload = {"app_metadata" => {"authorization" => {"roles" => ["member"]}}, "exp" => (Time.now + 600).to_i}
      token = JWT.encode payload, "foobar", 'HS256'
      m = redirector.match(stub_everything(path: "/member/users", cookies: {"nf_jwt" => token}))

      assert m
      assert_equal "app_metadata.authorization.roles:admin,member", redirector.conditions["JWT"]
    end

    def test_redirector_with_multiple_roles_with_string_payload
      redirector = RedirectMatcher.new([
        {:path => "/member/*", :to => "/member/:splat", :status => 200, :conditions => {"Role" => "admin,member"}}
      ], :jwt_secret => "foobar")

      payload = {"app_metadata" => {"authorization" => {"roles" => "member"}}, "exp" => (Time.now + 600).to_i}
      token = JWT.encode payload, "foobar", 'HS256'

      m = redirector.match(stub_everything(path: "/member/users", cookies: {"nf_jwt" => token}))

      assert_equal "app_metadata.authorization.roles:admin,member", redirector.conditions["JWT"]
    end

    def test_redirector_with_roles_falls_back_to_specific_role
      redirector = RedirectMatcher.new([
        {:path => "/admin/*", :to => "/admin/:splat", :status => 200, :conditions => {"Role" => "admin"}},
        {:path => "/admin/*", :to => "/admin/editor/:splat", :status => 200, :conditions => {"Role" => "editor"}}
      ], :jwt_secret => "foobar")

      payload = {"app_metadata" => {"authorization" => {"roles" => ["editor"]}}, "exp" => (Time.now + 600).to_i}
      token = JWT.encode payload, "foobar", 'HS256'

      m = redirector.match(stub_everything(path: "/admin/users", cookies: {"nf_jwt" => token}))

      assert_equal "app_metadata.authorization.roles:editor", redirector.conditions["JWT"]
    end

    def test_redirector_with_roles_falls_back_to_unauthorized
      redirector = RedirectMatcher.new([
        {:path => "/admin/*", :to => "/admin/:splat", :status => 200, :conditions => {"Role" => "admin"}},
        {:path => "/admin/*", :to => "/admin/editor/:splat", :status => 200, :conditions => {"Role" => "editor"}},
        {:path => "/admin/*", :to => "/404", :status => 404},
      ], :jwt_secret => "foobar")

      m = redirector.match(stub_everything(path: "/admin/users"))

      assert m
      assert m[:status] == 404
      assert_equal "app_metadata.authorization.roles:admin,editor", redirector.exceptions["JWT"]
      assert_nil redirector.conditions
    end

    def test_redirector_with_rules_with_login_fallback
      redirector = RedirectMatcher.new([
        {:path => "/admin/*", :to => "/admin/index.html", :status => 200, :force => true, :conditions => {"Role" => "admin"}},
        {:path => "/admin/*", :to => "/admin/login.html", :status => 200, :force => true},
      ], :jwt_secret => "foobar")

      m = redirector.match(stub_everything(path: "/admin/users"))

      assert_equal "app_metadata.authorization.roles:admin", redirector.exceptions["JWT"]
      assert_nil redirector.conditions
    end

    def test_redirector_with_rules_without_fallback
      redirector = RedirectMatcher.new([
        {:path => "/admin/*", :to => "/admin/index.html", :status => 200, :force => true, :conditions => {"Role" => "admin"}}
      ], :jwt_secret => "foobar")
      m = redirector.match(stub_everything(path: "/admin/users"))

      assert redirector.force404
      assert_equal "app_metadata.authorization.roles:admin", redirector.exceptions["JWT"]
      assert_nil redirector.conditions
    end

    def test_redirector_with_jwt_rules_for_proxying
      redirector = RedirectMatcher.new([
        {path: "/private-api/*",
          to: "https://rocky-beach-24637.herokuapp.com/private/:splat",
          status: 200,
          conditions: {"Role"=>["admin"]}
        }
      ], :jwt_secret => "foobar", :jwt_role_path => "app_metadata.roles")

      payload = {"app_metadata" => {"roles" => ["admin"]}, "exp" => (Time.now + 600).to_i}
      token = JWT.encode payload, "foobar", 'HS256'
      m = redirector.match(stub_everything(path: "/private-api/1234", cookies: {"nf_jwt" => token}))
      assert m
      assert_equal 200, m[:status]
      assert_equal "https://rocky-beach-24637.herokuapp.com/private/1234", m[:to]
    end
    # def test_redirector_with_expired_jwt_token
    #   redirector = RedirectMatcher.new([
    #     {:path => "/admin/*", :to => "/admin/:splat", :status => 200, :conditions => {"Role" => "admin"}},
    #     {:path => "/admin/*", :to => "/admin/login.html", :status => "200!"},
    #   ], :jwt_secret => "foobar")

    #   site.stubs(:jwt_secret).returns("foobar")
    #   site.stubs(:role_access_control_enabled?).returns(true)
    #   site.stubs(:jwt_role_path).with("admin").returns("app_metadata.authorization.roles:admin")

    #   payload = {"exp" => (Time.now - 30).to_i, "app_metadata" => {"authorization" => {"roles" => ["admin"]}}}
    #   token = JWT.encode payload, "foobar", 'HS256'

    #   clear_cookies
    #   set_cookie "nf_jwt=#{token}"
    #   get "/admin/users", {}, {'app.site' => site}

    #   assert last_response.ok?
    #   assert_equal "JWT=app_metadata.authorization.roles:admin", last_response.headers['X-BB-Except']
    #   assert last_response.headers.include?('Vary'), last_response.headers
    #   assert last_response.headers.include?("X-BB-JWT-Secret"), last_response.headers
    #   refute last_response.headers.include?('X-BB-Conditions'), last_response.headers
    # end

end
