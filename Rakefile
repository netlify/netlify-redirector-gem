require "bundler/gem_tasks"
require "rake/extensiontask"
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = "test/*_test.rb"
end

Rake::ExtensionTask.new "netlify_redirector" do |ext|
  ext.lib_dir = "lib/netlify_redirector"
end
