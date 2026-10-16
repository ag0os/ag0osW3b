# Puts this process in the tools bundle (tools/Gemfile), never the app's, and
# installs that bundle when it is missing. See DECISIONS.md, D-23.
#
# A bundled parent (bin/ci) hands its children the app's lockfile and a
# RUBYOPT that loads the app's bundle; `bundle check` would then write the
# tools' resolution into the app's Gemfile.lock. Frozen, a Gemfile that no
# longer matches its lockfile fails instead of resolving again.
gemfile = File.expand_path("Gemfile", __dir__)
tools = { "BUNDLE_GEMFILE" => gemfile, "BUNDLE_LOCKFILE" => "#{gemfile}.lock", "BUNDLE_FROZEN" => "true", "RUBYOPT" => nil }
system(tools, "bundle", "check", out: File::NULL) || system(tools, "bundle", "install", exception: true)

# Started from inside the app's bundle (bundle exec, or a RUBYOPT that loads
# it), the process starts again outside it.
if defined?(Bundler) && ENV["BUNDLE_GEMFILE"] != gemfile
  Bundler.with_unbundled_env { exec(tools, Gem.ruby, $PROGRAM_NAME, *ARGV) }
end
ENV.update(tools)

require "rubygems"
require "bundler/setup"
