# frozen_string_literal: true

require 'spec_helper'
require 'bridger/pipeline'

RSpec.describe Bridger::Pipeline do
  let(:initial_result) { Bridger::Result::Success.build }

  specify 'basic pipeline' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.step do |result|
        result.continue do |r|
          r.query[:name] = 'John'
        end
      end
      pl.step do |result|
        result.halt
      end
      pl.step do |result|
        result.continue do |r|
          r.query[:name] = 'Joe'
        end
      end
    end

    result = pipe.call(initial_result)
    expect(result.query[:name]).to eq('John')
    expect(result.halted?).to be(true)
  end

  specify '#halt helper' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.step do |result|
        result.continue(query: { name: 'John' })
      end
      pl.halt do |result|
        result.query[:name] = 'Halted'
      end
      pl.step do |result|
        result.continue(query: { name: 'Joe' })
      end
    end

    result = pipe.call(initial_result)
    expect(result.query[:name]).to eq('Halted')
    expect(result.halted?).to be(true)
  end

  specify '#continue helper' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.step do |result|
        result.continue(query: { name: 'John' })
      end
      pl.continue do |result|
        result.query[:name] = 'Continued'
      end
    end

    result = pipe.call(initial_result)
    expect(result.query[:name]).to eq('Continued')
    expect(result.halted?).to be(false)
  end

  specify '#step! runs for halts too' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.step do |result|
        result.continue(query: { name: 'John' })
      end
      pl.halt
      pl.step do |r|
        r.continue(query: { name: 'Joe' }) # will be skipped
      end
      pl.step! do |r| # will run even if result is halted
        r.continue(query: { name: 'Jane' })
      end
      pl.step do |r|
        r.continue(query: { name: r.query[:name] + ' Doe' })
      end
    end

    result = pipe.call(initial_result)
    expect(result.query[:name]).to eq('Jane Doe')
    expect(result.halted?).to be(false)
  end

  specify 'sub pipelines' do
    john = ->(result) { result.continue(query: { name: 'John' }) }
    doe = Bridger::Pipeline.new do |pl|
      pl.step do |r|
        r.continue(query: { name: r.query[:name] + ' Doe' })
      end
    end

    pipe = Bridger::Pipeline.new do |pl|
      pl.step john
      pl.step doe
      pl.pipeline do |p2|
        p2.step do |r|
          r.continue(query: { name: r.query[:name] + ' Jr.' })
        end
      end
    end

    result = pipe.call(initial_result)
    expect(result.query[:name]).to eq('John Doe Jr.')
  end
end
