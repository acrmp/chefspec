begin
  require 'berkshelf'
rescue LoadError
  raise RuntimeError, "Berkshelf not found! You must have the berkshelf" \
    " installed on your system before requiring chefspec/berkshelf. Install" \
    " berkshelf by running:\n\n  gem install berkshelf\n\nor add Berkshelf" \
    " to your Gemfile:\n\n  gem 'berkshelf'\n\n"
end

module ChefSpec
  class Berkshelf
    class << self
      extend Forwardable
      def_delegators :instance, :setup!, :teardown!
    end

    include Singleton

    def initialize
      @tmpdir = Dir.mktmpdir
    end

    #
    # Setup and install the necessary dependencies in the temporary directory.
    #
    def setup!
      ::Berkshelf.ui.mute do
        if ::Berkshelf::Berksfile.method_defined?(:vendor)
          FileUtils.rm_rf(@tmpdir) # Berksfile#vendor requires that the directory does't exist
          ::Berkshelf::Berksfile.from_file('Berksfile').vendor(@tmpdir)
        else
          ::Berkshelf::Berksfile.from_file('Berksfile').install(path: @tmpdir)
        end
      end

      ::RSpec.configure { |config| config.cookbook_path = @tmpdir }
    end

    #
    # Destroy the installed Berkshelf at the temporary directory.
    #
    def teardown!
      FileUtils.rm_rf(@tmpdir)
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) { ChefSpec::Berkshelf.setup! }
  config.after(:suite)  { ChefSpec::Berkshelf.teardown! }
end
