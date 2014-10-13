module Kernel
  # Kernel extension to print deprecation notices.
  #
  # @example printing a deprecation warning
  #   deprecated 'no longer in use' #=> "[DEPRECATION] no longer in use"
  #
  # @param [Array<String>] messages
  def deprecated(*messages)
    messages.each do |message|
      calling_spec = caller.find { |line| line =~ /(\/spec)|(_spec\.rb)/ }
      calling_spec = 'spec/' + calling_spec.split('/spec/').last
      warn "[DEPRECATION] #{message} (called from #{calling_spec})"
    end
  end
end

module ChefSpec
  class Runner
    # @deprecated {ChefSpec.define_runner_method} is deprecated. Please
    #   use {ChefSpec.define_runner_method} instead.
    def self.define_runner_method(resource_name)
      deprecated "`ChefSpec.define_runner_method' is deprecated. " \
        "Please use `ChefSpec.define_runner_method' instead."

      ChefSpec.define_matcher(resource_name)
    end

    # @deprecated {ChefSpec::Runner.new} is deprecated. Please use
    #   {ChefSpec::SoloRunner} or {ChefSpec::ServerRunner} instead.
    def self.new(*args, &block)
      deprecated "`ChefSpec::Runner' is deprecated. Please use" \
        " `ChefSpec::SoloRunner' or `ChefSpec::ServerRunner' instead."

      ChefSpec::SoloRunner.new(*args, &block)
    end
  end

  class Server
    def self.method_missing(m, *args, &block)
      deprecated "`ChefSpec::Server.#{m}' is deprecated. There is no longer" \
        " a global Chef Server instance. Please use a ChefSpec::ServerRunner" \
        " instead. More documentation can be found in the ChefSpec README."
      raise NoConversionError
    end
  end
end

module ChefSpec::Error
  class NoConversionError < ChefSpecError;  end
end
