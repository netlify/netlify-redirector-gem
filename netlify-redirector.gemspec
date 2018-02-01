# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'netlify_redirector/version'

Gem::Specification.new do |spec|
  spec.name          = "netlify_redirector"
  spec.version       = NetlifyRedirector::VERSION
  spec.authors       = ["Mathias Biilmann Christensen"]
  spec.email         = ["info@mathias-biilmann.net"]
  spec.summary       = %q{Parses and matches redirect rules}
  spec.description   = %q{Netlify Redirector parses and crunches redirect rules}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib", "ext"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "minitest", "~> 5.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "mocha", "~> 1.2"
  spec.add_development_dependency "rake-compiler", "~> 0.9"
  spec.add_development_dependency "pkg-config", "~> 1.1.7"
  spec.add_development_dependency "jwt", "~> 1.5.6"

  spec.extensions = %w{ext/netlify_redirector/extconf.rb}
end
