# Loads the app for mutant (config/mutant.yml). Every constant must be loaded
# before mutant matches subjects, so eager load.
require_relative "../../config/environment"
Rails.application.eager_load!

# Load only tests that declare the subjects they cover, keeping unrelated
# suites and the Chrome system-test driver out of mutant's test discovery.
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
