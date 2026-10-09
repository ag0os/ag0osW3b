# Loads the app for mutant (config/mutant.yml). Every constant must be loaded
# before mutant matches subjects, so eager load.
require_relative "../../config/environment"
Rails.application.eager_load!

# The integration requires every test file, and test/system and
# test/integration both define ShellTest with different superclasses. Only tests
# with a `cover` declaration are ever selected, so load just those files.
require "mutant/integration/minitest"
Mutant::Integration::Minitest.prepend(Module.new do
  def setup
    Pathname.glob("test/**/*_test.rb")
      .select { |path| path.read.match?(/^\s*cover\b/) }
      .each { |path| require path.expand_path.to_s }
    ::Minitest.seed ||= world.random.srand
    self
  end
end)
