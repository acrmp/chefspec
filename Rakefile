require 'bundler/gem_tasks'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'yard/rake/yardoc_task'
require 'tmpdir'
require 'rspec'
require 'chefspec'

require 'chef/version'

YARD::Rake::YardocTask.new

RSpec::Core::RakeTask.new(:unit) do |t|
  t.rspec_opts = [].tap do |a|
    a.push('--color')
    a.push('--format progress')
  end.join(' ')
end

failed = []
start_time = nil

namespace :acceptance do |ns|
  Dir.foreach("examples") do |dir|
    next if dir == '.' or dir == '..'
    desc "#{dir} acceptance tests"
    task dir.to_sym do
      start_time ||= Time.now
      Dir.mktmpdir do |tmp|
        FileUtils.cp_r("examples/#{dir}", tmp)

        pwd = Dir.pwd

        Dir.chdir "#{tmp}/#{dir}" do
          puts "rspec examples/#{dir}"

          #
          # This bit of mildly awful magic below is to load each file into an in-memory
          # RSpec runner while keeping a persistent ChefZero server alive.
          #
          load "#{pwd}/lib/chefspec/rspec.rb"

          # load policyfile for each cookbook so that setup/teardown are triggered
          if dir.start_with?('policy_file')
            begin
              load "#{pwd}/lib/chefspec/policyfile.rb"
            rescue LoadError, ChefSpec::Error::GemLoadError
              # skip if we don't have ChefDK gem installed
              puts "Skipping #{dir}. No ChefDK Gem installed", nil
              next
            end
          end

          RSpec.configure do |config|
            config.color = true
            config.run_all_when_everything_filtered = true
            config.filter_run(:focus)
            config.before(:suite) do
              ChefSpec::ZeroServer.setup!
            end
            config.after(:each) do
              # reset so policy file cookbooks can be found
              Chef::Config[:chefspec_cookbook_root] = nil
              ChefSpec::ZeroServer.reset!
            end
          end

          RSpec.clear_examples
          exitstatus = RSpec::Core::Runner.run(["spec"])
          RSpec.reset
          failed << dir unless exitstatus == 0
        end
      end
    end
  end
end

task acceptance: Rake.application.tasks.select { |t| t.name.start_with?("acceptance:") } do
  puts "Acceptance tests took #{Time.now - start_time} seconds"
  raise "some tests failed: #{failed.join(', ')}" unless failed.empty?
end

desc 'Run all tests'
task :test => [:unit, :acceptance]

task :default => [:test]
