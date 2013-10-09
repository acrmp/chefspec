require 'fauxhai'
require 'chef/client'
require 'chef/mash'
require 'chef/providers'
require 'chef/resources'

module ChefSpec
  class Runner
    #
    # Defines a new runner method on the +ChefSpec::Runner+.
    #
    # @param [Symbol] resource_name
    #   the name of the resource to define a method
    #
    # @return [self]
    #
    def self.define_runner_method(resource_name)
      define_method(resource_name) do |identity|
        find_resource(resource_name, identity)
      end

      self
    end

    # @return [Hash]
    attr_reader :options

    # @return [Chef::RunContext]
    attr_reader :run_context

    #
    # Instantiate a new Runner to run examples with.
    #
    # @example Instantiate a new Runner
    #   ChefSpec::Runner.new
    #
    # @example Specifying the platform and version
    #   ChefSpec::Runner.new(platform: 'ubuntu', version: '12.04')
    #
    # @example Specifying the cookbook path
    #   ChefSpec::Runner.new(cookbook_path: ['/cookbooks'])
    #
    # @example Specifying the log level
    #   ChefSpec::Runner.new(log_level: :info)
    #
    #
    # @param [Hash] options
    #   The options for the new runner
    #
    # @option options [Symbol] :log_level
    #   The log level to use (default is :warn)
    # @option options [String] :platform
    #   The platform to load Ohai attributes from (must be present in fauxhai)
    # @option options [String] :version
    #   The version of the platform to load Ohai attributes from (must be present in fauxhai)
    # @option options [String] :path
    #   Path of a json file that will be passed to fauxhai as :path option
    # @option options [Array<String>] :step_into
    #   The list of LWRPs to evaluate
    #
    # @yield [node] Configuration block for Chef::Node
    #
    def initialize(options = {}, &block)
      @options = options = {
        cookbook_path: RSpec.configuration.cookbook_path || calling_cookbook_path(caller),
        log_level:     RSpec.configuration.log_level,
        path:          RSpec.configuration.path,
        platform:      RSpec.configuration.platform,
        version:       RSpec.configuration.version,
      }.merge(options)

      Chef::Log.level = options[:log_level]

      Chef::Config.reset!
      Chef::Config.formatters.clear
      Chef::Config.add_formatter('chefspec')
      Chef::Config[:cache_type]    = 'Memory'
      Chef::Config[:cookbook_path] = Array(options[:cookbook_path])
      Chef::Config[:force_logger]  = true
      Chef::Config[:solo]          = true

      yield node if block_given?
    end

    #
    # Execute the specified recipes on the node, without actually converging
    # the node. This is the equivalent of `chef-apply`.
    #
    # @example Converging a single recipe
    #   chef_run.apply('example::default')
    #
    # @example Converging multiple recipes
    #   chef_run.apply('example::default', 'example::secondary')
    #
    #
    # @param [Array] recipe_names
    #   The names of the recipe or recipes to apply
    #
    # @return [ChefSpec::Runner]
    #   A reference to the calling Runner (for chaining purposes)
    #
    def apply(*recipe_names)
      recipe_names.each do |recipe_name|
        cookbook, recipe = Chef::Recipe.parse_recipe_name(recipe_name)
        recipe_path = File.join(Dir.pwd, 'recipes', "#{recipe}.rb")

        recipe = Chef::Recipe.new(cookbook, recipe, run_context)
        recipe.from_file(recipe_path)
      end

      @resources = {}
      @run_context = Chef::RunContext.new(client.node, {}, client.events)

      Chef::Runner.new(@run_context).converge
      self
    end

    #
    # Execute the given `run_list` on the node, without actually converging
    # the node.
    #
    # @example Converging a single recipe
    #   chef_run.converge('example::default')
    #
    # @example Converging multiple recipes
    #   chef_run.converge('example::default', 'example::secondary')
    #
    #
    # @param [Array] recipe_names
    #   The names of the recipe or recipes to converge
    #
    # @return [ChefSpec::Runner]
    #   A reference to the calling Runner (for chaining purposes)
    #
    def converge(*recipe_names)
      node.run_list.reset!
      recipe_names.each { |recipe_name| node.run_list.add(recipe_name) }

      return self if dry_run?

      # Reset the resource collection
      @resources = {}

      client.build_node
      @run_context = client.setup_run_context

      Chef::Runner.new(@run_context).converge
      self
    end

    #
    # The +Chef::Node+ corresponding to this Runner.
    #
    # @return [Chef::Node]
    #
    def node
      return @node if @node

      @node = client.node
      @node.instance_variable_set(:@runner, self)
      @node.class.send(:attr_reader, :runner)
      @node
    end

    #
    # The full collection of resources for this Runner.
    #
    # @return [Hash<String, Chef::Resource>]
    #
    def resources
      @resources ||= {}
    end

    #
    # Find the resource with the declared type and resource name.
    #
    # @example Find a template at `/etc/foo`
    #   chef_run.find_resource(:template, '/etc/foo') #=> #<Chef::Resource::Template>
    #
    #
    # @param [Symbol] type
    #   The type of resource (sometimes called `resource_name`) such as `file`
    #   or `directory`.
    # @param [String, Regexp] name
    #   The value of the name attribute or identity attribute for the resource.
    #
    # @return [Chef::Resource, nil]
    #   The matching resource, or nil if one is not found
    #
    def find_resource(type, name)
      return resources["#{type}[#{name}]"] if resources["#{type}[#{name}]"]

      resources.values.find do |resource|
        resource.resource_name.to_sym == type && (name === resource.identity || name === resource.name)
      end
    end

    #
    # Find the resource with the declared type.
    #
    # @example Find all template resources
    #   chef_run.find_resources('template') #=> [#<Chef::Resource::Template>, #...]
    #
    #
    # @param [Symbol] type
    #   The type of resource such as `:file` or `:directory`.
    #
    # @return [Array<Chef::Resource>]
    #   The matching resources
    #
    def find_resources(type)
      resources.select do |_, resource|
        resource.resource_name.to_s == type.to_s
      end
    end

    #
    # The list of LWRPs to step into and evaluate.
    #
    # @return [Array<String>]
    #
    def step_into
      @step_into ||= Array(options[:step_into] || [])
    end

    #
    # Boolean method to determine if this Runner is in `dry_run` mode.
    #
    # @return [Boolean]
    #
    def dry_run?
      !!options[:dry_run]
    end

    #
    # This runner as a string.
    #
    # @return [String] Currently includes the run_list. Format of the string may change between versions of this gem.
    #
    def to_s
      return "chef_run: #{node.run_list.to_s}" unless node.run_list.empty?
      'chef_run'
    end

    #
    # The runner as a String with helpful output.
    #
    # @return [String]
    #
    def inspect
      "#<#{self.class} options: #{options.inspect}, run_list: '#{node.run_list.to_s}'>"
    end

    private
      def calling_cookbook_path(kaller)
        calling_spec = kaller.find { |line| line =~ /\/spec/ }
        bits = calling_spec.split(':', 2).first.split(File::SEPARATOR)
        spec_dir = bits.index('spec') || 0

        File.expand_path(File.join(bits.slice(0, spec_dir), '..'))
      end

      #
      def client
        return @client if @client

        @client = Chef::Client.new
        @client.ohai.data = Mash.from_hash(Fauxhai.mock(options).data)
        @client.load_node
        @client.build_node
        @client
      end
  end
end
