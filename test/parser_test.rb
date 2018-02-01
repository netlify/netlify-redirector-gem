require 'minitest/autorun'
require 'netlify_redirector'

class RedirectParser
  def parse(source)
    result = NetlifyRedirector.parse(source)
    Struct.new(:success, :errors).new(result[:success], result[:errors])
  end
end

class TestRedirectParser < MiniTest::Unit::TestCase
  def with_parsed_result(source, &block)
    parser = RedirectParser.new

    result = parser.parse(source)
    block.call(result)
  end

  def test_simple_redirects
    source = %[
/home              /
/blog/my-post.php  /blog/my-post # this is just an old leftover
/blog/my-post-ads.php  /blog/my-post#ads # this is a valid anchor with a comment
/news              /blog
]
    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/home", :to => "/", :status => 301},
        {:path => "/blog/my-post.php", :to => "/blog/my-post", :status => 301},
        {:path => "/blog/my-post-ads.php", :to => "/blog/my-post#ads", :status => 301},
        {:path => "/news", :to => "/blog", :status => 301}
      ], result.success
    end
  end

  def test_redirects_with_status_codes
    source = %[
/home         /              301
/my-redirect  /              302
/pass-through /              200
/ecommerce    /store-closed  404
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/home", :to => "/", :status => 301},
        {:path => "/my-redirect", :to => "/", :status => 302},
        {:path => "/pass-through", :to => "/", :status => 200},
        {:path => "/ecommerce", :to => "/store-closed", :status => 404}
      ], result.success
    end
  end

  def test_redirects_with_parameter_matches
    source = %[
/      page=news      /news
/blog  post=:post_id  /blog/:post_id
/      _escaped_fragment_=/about    /about   301
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/", :to => "/news", :params => {:page => "news"}, :status => 301},
        {:path => "/blog", :to => "/blog/:post_id", :params => {:post => ":post_id"}, :status => 301},
        {:path => "/", :to => "/about", :params => {:_escaped_fragment_ => "/about"}, :status => 301}
      ], result.success.map(&:to_hash)
    end
  end

  def test_redirects_with_full_hostname
    source = %[
http://hello.bitballoon.com/* http://www.hello.com/:splat
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:host => "hello.bitballoon.com", :scheme => "http", :path => "/*", :to => "http://www.hello.com/:splat", :status => 301}
      ], result.success.map(&:to_hash)
    end
  end

  def test_proxy_instruction
    source = %[
/api/*  https://api.bitballoon.com/*   200
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/api/*", :to => "https://api.bitballoon.com/*", :status => 200, :proxy => true}
      ], result.success.map(&:to_hash)
    end
  end

  def test_redirect_country_conditions
    source = %[
/  /china 302 Country=ch,tw
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/", :to => "/china", :status => 302, :conditions => {"Country" => "ch,tw"}}
      ], result.success.map(&:to_hash)
    end
  end

  def test_redirect_Country_and_Language_conditions
    source = %[
/  /china 302 Country=il Language=en
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/", :to => "/china", :status => 302, :conditions => {"Country" => "il", "Language" => "en"}}
      ], result.success.map(&:to_hash)
    end
  end

  def test_splat_based_redirect_with_force_instruction
    source = %[/*  https://www.bitballoon.com/:splat 301]
    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/*", :to => "https://www.bitballoon.com/:splat", :status => 301}
      ], result.success.map(&:to_hash)
    end

    source = %[/*  https://www.bitballoon.com/:splat 301!]
    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/*", :to => "https://www.bitballoon.com/:splat", :status => 301, :force => true}
      ], result.success.map(&:to_hash)
    end
  end

  def test_redirect_rule_with_equal
    source = %[/test https://www.bitballoon.com/test=hello 301]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/test", :to => "https://www.bitballoon.com/test=hello", :status => 301}
      ], result.success.map(&:to_hash)
    end
  end

  def test_real_client_rules
    cases = [
      {
        :source => %[/donate source=:source email=:email /donate/usa?source=:source&email=:email 302 Country=us],
        :result => [{:path => "/donate", :to => "/donate/usa?source=:source&email=:email", :params => {:source => ":source", :email => ":email"}, :status => 302, :conditions => {"Country" => "us"}}]
      },
      {
        :source => %[/ https://origin.wework.com 200],
        :result => [{:path => "/", :to => "https://origin.wework.com", :status => 200, :proxy => true}]
      },
      {
        :source => %[/:lang/locations/* /locations/:splat 200],
        :result => [{:path => "/:lang/locations/*", :to => "/locations/:splat", :status => 200 }]
      }
    ]
    cases.each do |c|
      with_parsed_result(c[:source]) do |result|
        assert_equal c[:result], result.success.map(&:to_hash)
      end
    end
  end

  def test_rules_with_no_destination
    source = "/swfobject.html?detectflash=false 301"
    with_parsed_result(source) do |result|
      assert_equal [], result.success
      assert_equal 1, result.errors.size
    end
  end

  def test_rules_with_complex_redirections
    source = """
/google-play                https://goo.gl/app/playmusic?ibi=com.google.PlayMusic&isi=691797987&ius=googleplaymusic&link=https://play.google.com/music/m/Ihj4yege3lfmp3vs5yoopgxijpi?t%3DArrested_DevOps            301!
"""

    parser = RedirectParser.new
    # the new parser knows how to handle more complex "to" rules
    result = parser.parse(source)

    assert result.errors.empty?
    assert_equal 1, result.success.size
    assert_equal "https://goo.gl/app/playmusic?ibi=com.google.PlayMusic&isi=691797987&ius=googleplaymusic&link=https://play.google.com/music/m/Ihj4yege3lfmp3vs5yoopgxijpi?t%3DArrested_DevOps", result.success.first[:to]
  end

  def test_rules_complicated_file
    source = """/10thmagnitude               http://www.10thmagnitude.com/                             301!
/bananastand                http://eepurl.com/Lgde5            301!
/conf                 https://docs.google.com/forms/d/1wMBXPjAcofBDqnRhKbM5KhzUbGPoxqRQZs6O_TEBa_Q/viewform?usp=send_form            301!
/gpm                https://goo.gl/app/playmusic?ibi=com.google.PlayMusic&isi=691797987&ius=googleplaymusic&link=https://play.google.com/music/m/Ihj4yege3lfmp3vs5yoopgxijpi?t%3DArrested_DevOps            301!
/googleplay                https://goo.gl/app/playmusic?ibi=com.google.PlayMusic&isi=691797987&ius=googleplaymusic&link=https://play.google.com/music/m/Ihj4yege3lfmp3vs5yoopgxijpi?t%3DArrested_DevOps            301!
/google-play-music                https://goo.gl/app/playmusic?ibi=com.google.PlayMusic&isi=691797987&ius=googleplaymusic&link=https://play.google.com/music/m/Ihj4yege3lfmp3vs5yoopgxijpi?t%3DArrested_DevOps            301!
/google                https://goo.gl/app/playmusic?ibi=com.google.PlayMusic&isi=691797987&ius=googleplaymusic&link=https://play.google.com/music/m/Ihj4yege3lfmp3vs5yoopgxijpi?t%3DArrested_DevOps            301!
/playmusic                https://goo.gl/app/playmusic?ibi=com.google.PlayMusic&isi=691797987&ius=googleplaymusic&link=https://play.google.com/music/m/Ihj4yege3lfmp3vs5yoopgxijpi?t%3DArrested_DevOps            301!
/google-play                https://goo.gl/app/playmusic?ibi=com.google.PlayMusic&isi=691797987&ius=googleplaymusic&link=https://play.google.com/music/m/Ihj4yege3lfmp3vs5yoopgxijpi?t%3DArrested_DevOps            301!
/guestform  https://docs.google.com/forms/d/1zqG3fEyugSQLt-yKJNsPpgqDr0Akl8hD_z4DaGdzuOI/viewform?usp=send_form 301!
/iphone http://itunes.apple.com/us/app/arrested-devops/id963732227 301!
/itunes https://itunes.apple.com/us/podcast/arrested-devops/id773888088?mt=2&uo=4&at=11lsCi 301!
/iTunes https://itunes.apple.com/us/podcast/arrested-devops/id773888088?mt=2&uo=4&at=11lsCi 301!
/mailinglist http://eepurl.com/Lgde5 301!
/sponsorschedule http://docs.google.com/spreadsheets/d/1wkWhmSIC_WYultwRb6jfQijrfS1x44YIyCV_pBJxgRQ/pubhtml?gid=67301010&single=true 301!
/stackexchange http://careers.stackoverflow.com/jobs/employer/Stack%20Exchange?searchTerm=Reliability 301!
/tenthmagnitude http://www.10thmagnitude.com/ 301!
/xm http://www.10thmagnitude.com/ 301!
/codeship http://www.codeship.io/arresteddevops?utm_source=arresteddevops&utm_medium=podcast&utm_campaign=ArrestedDevOpsPodcast 301!
/datadog https://www.datadoghq.com/lpgs/?utm_source=Advertisement&utm_medium=Advertisement&utm_campaign=ArrestedDevops-Tshirt 301!
/loggly https://www.loggly.com/?utm_source=arresteddevops&utm_medium=podcast&utm_campaign=1 301!
/redgate http://www.red-gate.com/products/dlm/?utm_source=arresteddevops&utm_medium=displayad&utm_content=dlm&utm_campaign=dlm&utm_term=podcast-22752 301!
/trueability http://linux.trueability.com 301!
/hired https://hired.com/?utm_source=podcast&utm_medium=arresteddevops&utm_campaign=q2-16&utm_term=cat-tech-devops 301!
/stickers https://www.stickermule.com/user/1070633194/stickers 301!
/chefcommunity  https://summit.chef.io 301!
"""

    parser = RedirectParser.new
    result = parser.parse(source)

    assert result.errors.empty?

    assert_equal 26, result.success.size
    result.success.each do |r|
      assert r[:to].start_with?("http")
    end
  end

  def test_410_rule
    source = "/m/scge/team/growth /404  410"

    parser = RedirectParser.new
    result = parser.parse(source)
    assert_equal([{:path => "/m/scge/team/growth", :to => "/404", :status => 410}], result.success, result.errors)
  end

  def test_rules_long_file
    source = File.read(File.expand_path("../data/redirects", __FILE__))

    parser = RedirectParser.new
    result = parser.parse(source)

    assert_equal [33, 640, 734, 917, 918, 919, 920, 987], result.errors.keys # lines with invalid redirect rules
    refute result.success.empty?
  end

  def test_absolute_redirects_with_country_conditions
    source = %[ # Send all traffic from Australia to the right country URL
 http://ximble.com.au/* https://www.ximble.com/au/:splat 301! Country=au
 http://www.ximble.com.au/* https://www.ximble.com/au/:splat 301! Country=au
 https://ximble.com.au/* https://www.ximble.com/au/:splat 301! Country=au
 https://www.ximble.com.au/* https://www.ximble.com/au/:splat 301! Country=au
 https://www.ximble.com/* https://www.ximble.com/au/:splat 301! Country=au

  # Pages on NimbleSchedule.com that have changed
  /about-us     /about
  /easy-employee-scheduling/    /scheduling
]
    parser = RedirectParser.new
    result = parser.parse(source)

    expected = {
      :host=>"ximble.com.au",
      :scheme=>"http",
      :path=>"/*",
      :to=>"https://www.ximble.com/au/:splat",
      :status=>301,
      :force=>true,
      :conditions=>{"Country"=>"au"}
    }

    assert_equal expected, result.success.first
  end

  def test_redirect_role_conditions
    source = %[
/admin/*  /admin/:splat 200 Role=admin
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/admin/*", :to => "/admin/:splat", :status => 200, :conditions => {"Role" => "admin"}}
      ], result.success.map(&:to_hash)
    end
  end

  def test_redirect_role_multiple_conditions
    source = %[
/member/*  /member/:splat 200 Role=admin,member
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/member/*", :to => "/member/:splat", :status => 200, :conditions => {"Role" => "admin,member"}}
      ], result.success.map(&:to_hash)
    end
  end

  def test_parse_forward_rule
    source = %[
/admin/* 200
/admin/* 200!
    ]

    with_parsed_result(source) do |result|
      assert_equal [
        {:path => "/admin/*", :to => "/admin/:splat", :status => 200},
        {:path => "/admin/*", :to => "/admin/:splat", :status => 200, :force => true}
      ], result.success.map(&:to_hash)
    end

    with_parsed_result("/admin/* 301") do |result|
      assert_equal [], result.success
      assert_equal 1, result.errors.size
    end
  end

  # require 'benchmark'
  # def test_benchmark_rules_long_file
  #   source = File.read(File.expand_path("../data/redirects", __FILE__))
  #
  #   parser = RedirectParser.new
  #   puts Benchmark.measure {
  #     5000.times do
  #       result = parser.parse(source)
  #     end
  #   }
  # end
end
