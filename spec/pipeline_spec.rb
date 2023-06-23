# frozen_string_literal: true

require 'spec_helper'
require 'bridger/pipeline'

module PipelineTest
  module With
    def with(**kwargs)
      self.class.new(to_h.merge(kwargs))
    end
  end

  Result = Struct.new(:name, keyword_init: true) do
    include With

    def halted?
      false
    end

    def halt(&block)
      result = self
      if block_given?
        result = dup
        yield result
      end
      Halt.new(name: result.name)
    end

    def continue(&block)
      return self unless block_given?

      result = self.dup
      yield result
      result
    end
  end

  Halt = Struct.new(:name, keyword_init: true) do
    include With

    def halted?
      true
    end

    def continue(&block)
      result = self.dup
      yield result if block_given?
      Result.new(name: result.name)
    end
  end
end

RSpec.describe Bridger::Pipeline do
  specify 'basic pipeline' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.step do |result|
        result.with(name: 'John')
      end
      pl.step do |result|
        PipelineTest::Halt.new(name: result.name)
      end
      pl.step do |result|
        result.with(name: 'Joe')
      end
    end

    result = pipe.call(PipelineTest::Result.new(name: ''))
    expect(result.name).to eq('John')
    expect(result.halted?).to be(true)
  end

  specify '#halt helper' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.step do |result|
        result.with(name: 'John')
      end
      pl.halt do |result|
        result.name = 'Halted'
      end
      pl.step do |result|
        result.with(name: 'Joe')
      end
    end

    result = pipe.call(PipelineTest::Result.new(name: ''))
    expect(result.name).to eq('Halted')
    expect(result.halted?).to be(true)
  end

  specify '#continue helper' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.step do |result|
        result.with(name: 'John')
      end
      pl.continue do |result|
        result.name = 'Continued'
      end
    end

    result = pipe.call(PipelineTest::Result.new(name: ''))
    expect(result.name).to eq('Continued')
    expect(result.halted?).to be(false)
  end

  specify '#step! runs for halts too' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.step do |result|
        result.with(name: 'John')
      end
      pl.halt
      pl.step do |r|
        r.with(name: 'Joe') # will be skipped
      end
      pl.step! do |r| # will run even if result is halted
        r.continue do |r|
          r.name = 'Jane'
        end
      end
      pl.step do |r|
        r.with(name: r.name + ' Doe')
      end
    end

    result = pipe.call(PipelineTest::Result.new(name: ''))
    expect(result.name).to eq('Jane Doe')
    expect(result.halted?).to be(false)
  end

  specify 'sub pipelines' do
    john = ->(result) { result.with(name: 'John') }
    doe = Bridger::Pipeline.new do |pl|
      pl.step do |r|
        r.with(name: r.name + ' Doe')
      end
    end

    pipe = Bridger::Pipeline.new do |pl|
      pl.step john
      pl.step doe
      pl.pipeline do |p2|
        p2.continue do |r|
          r.name = r.name + ' Jr.'
        end
      end
    end

    result = pipe.call(PipelineTest::Result.new(name: ''))
    expect(result.name).to eq('John Doe Jr.')
  end
end
