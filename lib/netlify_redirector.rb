require "netlify_redirector/version"
require "netlify_redirector/netlify_redirector"

class NetlifyRedirector
  DEFAULT_ROLE_CLAIM = "app_metadata.authorization.roles"

  def match(redirects, request, secret = nil, roleClaim = nil)
    match_rules(redirects, request, secret, roleClaim || DEFAULT_ROLE_CLAIM)
  end
end
