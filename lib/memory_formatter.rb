require 'rspec/core/formatters/progress_formatter'
require 'newrelic_rpm'
require 'active_support/core_ext/module/delegation'

class ProfileData < Hash
  include Singleton

  def sorted
    self.class[sort_by{ |_, data| -(data[:end] - data[:start]) }]
  end

  def top(limit = 10)
    self.class[sorted.first(limit)]
  end
end

class MemoryFormatter < ::RSpec::Core::Formatters::BaseTextFormatter
  def initialize(*)
    super
    @data = ProfileData.instance
  end

  def message(*)
    # do nothing
  end

  def example_started(example)
    path = example.metadata[:example_group][:file_path]
    line = example.metadata[:line_number]

    @data[example.object_id] = {
      description: example.metadata.full_description,
      path: "#{path}:#{line}",
      start: NewRelic::Agent::Samplers::MemorySampler.new.sampler.get_sample
    }

    # super
  end

  def example_passed(example)
    @data[example.object_id][:end] = NewRelic::Agent::Samplers::MemorySampler.new.sampler.get_sample
  end

  alias_method :example_failed, :example_passed
  alias_method :example_pending, :example_passed

  def dump_failures
    top = @data.top

    puts
    puts "Top #{top.count} most memory consumed:"

    top.values.each do |data|
      puts "  #{data[:description]}"
      puts "    #{color("%.3fMB" % [data[:end] - data[:start]], RSpec.configuration.failure_color)} #{data[:path]}"
    end
  end

  def dump_summary(*)

  end
end
