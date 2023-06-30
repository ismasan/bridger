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

  specify '#query_schema' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.query_schema do
        field(:name).type(:string).required
        field(:age).type(:integer).required
      end
      pl.step do |r|
        r.continue(context: { foo: 'bar' })
      end
      pl.pipeline do |p2|
        p2.query_schema do
          field(:title).type(:string).default('Mr.')
        end
      end
    end

    expect(pipe.query_schema).to be_a(Parametric::Schema)
    expect(pipe.query_schema.fields.keys).to eq(%i[name age title])
  end

  specify '#payload_schema' do
    pipe = Bridger::Pipeline.new do |pl|
      pl.payload_schema do
        field(:name).type(:string).required
        field(:age).type(:integer).required
      end
      pl.step do |r|
        r.continue(context: { foo: 'bar' })
      end
      pl.pipeline do |p2|
        p2.payload_schema do
          field(:title).type(:string).default('Mr.')
        end
      end
    end

    expect(pipe.payload_schema).to be_a(Parametric::Schema)
    expect(pipe.payload_schema.fields.keys).to eq(%i[name age title])
  end

  describe '#run' do
    let(:initial_result) { Bridger::Result::Success.build(query:, payload:) }

    let(:query) { { name: 'John', age: '42' } }
    let(:payload) { { title: 'Mr.', foo: 'bar' } }

    let(:pipe) do
      Bridger::Pipeline.new do |pl|
        pl.query_schema do
          field(:name).type(:string).required
          field(:age).type(:integer).required
        end
        pl.payload_schema do
          field(:title).type(:string).required
        end

        pl.step do |r|
          r.continue(data: { name: "#{r.payload[:title]} #{r.query[:name]}" })
        end

        pl.step! do |r|
          r.copy(data: r.data.merge(always_run: true))
        end
      end
    end

    it 'resolves query and payload' do
      result = pipe.run(initial_result)
      expect(result.valid?).to be(true)
      expect(result.query).to eq(age: 42, name: 'John')
      expect(result.payload).to eq(title: 'Mr.')
      expect(result.data[:name]).to eq('Mr. John')
      expect(result.data[:always_run]).to be(true)
    end

    context 'with invalid payload' do
      let(:payload) { { foo: 'bar' } }

      it 'collects errors' do
        result = pipe.run(initial_result)
        expect(result.valid?).to be(false)
        expect(result.halted?).to be(true)
        expect(result.errors['$.title']).to eq(['is required'])
        expect(result.data[:name]).to be_nil
        expect(result.data[:always_run]).to be(true)
      end
    end
  end
end
