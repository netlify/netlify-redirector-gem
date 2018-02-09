require 'mkmf'

def package_config(pkg, options={})
  package = pkg_config(pkg)
  return package if package

  begin
    require 'rubygems'
    gem 'pkg-config', (gem_ver='~> 1.1.7')
    require 'pkg-config' and message("Using pkg-config gem version #{PKGConfig::VERSION}\n")
  rescue LoadError
    message "pkg-config could not be used to find #{pkg}\nPlease install either `pkg-config` or the pkg-config gem per\n\n    gem install pkg-config -v #{gem_ver.inspect}\n\n"
  else
    return nil unless PKGConfig.have_package(pkg)

    cflags  = PKGConfig.cflags(pkg)
    ldflags = PKGConfig.libs_only_L(pkg)
    libs    = PKGConfig.libs_only_l(pkg)

    Logging::message "PKGConfig package configuration for %s\n", pkg
    Logging::message "cflags: %s\nldflags: %s\nlibs: %s\n\n", cflags, ldflags, libs

    [cflags, ldflags, libs]
  end
end

extension_name = 'netlify_redirector'

$CXXFLAGS << " -std=c++11 -fPIC -c -Wall -Wno-sign-compare -O3 -g"

LIBDIR     = RbConfig::CONFIG['libdir']
INCLUDEDIR = RbConfig::CONFIG['includedir']

HEADER_DIRS = [INCLUDEDIR, File.expand_path(File.join(File.dirname(__FILE__), "include"))]

# setup constant that is equal to that of the file path that holds that static libraries that will need to be compiled against
LIB_DIRS = [LIBDIR, File.expand_path(File.join(File.dirname(__FILE__), "lib"))]
libs = []
case RUBY_PLATFORM
when /darwin/
  libs << '-lnetlify-redirects_darwin'
when /linux/
  libs << '-lnetlify-redirects_linux'
else
  raise "Unsupported platform"
end

dir_config('openssl').any? or package_config('openssl')
dir_config(extension_name, HEADER_DIRS, LIB_DIRS)       # The destination

libs.each do |lib|
  $LOCAL_LIBS << "#{lib} "
end

create_makefile(extension_name)  # Create Makefile
