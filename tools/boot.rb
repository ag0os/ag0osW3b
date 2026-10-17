# Puts this process in the tools bundle (tools/Gemfile), never the app's, and
# installs that bundle when it is missing. See DECISIONS.md, D-23.
gemfile = File.expand_path("Gemfile", __dir__)
tools = { "BUNDLE_GEMFILE" => gemfile, "BUNDLE_LOCKFILE" => "#{gemfile}.lock", "BUNDLE_FROZEN" => "true", "RUBYOPT" => nil }

# Started from inside the app's bundle (bundle exec, or a RUBYOPT that loads
# it, as bin/ci's children are), the process starts again outside it before
# installing anything. The app's bundle hands its children its lockfile, which
# `bundle check` would write the tools' resolution into; BUNDLER_SETUP, which
# RubyGems requires at startup, so `bundle install` would load the bundle it is
# about to install and stop on the missing gems; and, with a bundle path such
# as setup-ruby's vendor/bundle, a GEM_HOME and GEM_PATH that hide the
# installed Bundler. The unbundled environment has none of them.
if defined?(Bundler) && ENV["BUNDLE_GEMFILE"] != gemfile
  Bundler.with_unbundled_env { exec(tools, Gem.ruby, $PROGRAM_NAME, *ARGV) }
end

# Frozen, a Gemfile that no longer matches its lockfile fails instead of
# resolving again.
system(tools, "bundle", "check", out: File::NULL) || system(tools, "bundle", "install", exception: true)
ENV.update(tools)

require "rubygems"
require "bundler/setup"
