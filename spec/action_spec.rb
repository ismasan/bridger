# frozen_string_literal: true

RSpec.describe Bridger::Action do
  subject(:action) do
    Class.new(Bridger::Action) do
      payload_schema do
        field(:age).type(:integer).default(40)
        field(:name).type(:string).present
      end

      def run(result)
        result.continue("Mr. #{result.payload[:name]}")
      end
    end
  end

  specify '#payload_schema' do
    expect(action.payload_schema.fields.keys).to eq(%i[age name])
  end

  specify '#query_schema' do
    expect(action.query_schema).to be_a(Parametric::Schema)
  end

  specify 'valid payload' do
    initial = Bridger::Result::Success.build(payload: { name: 'John' })
    result = action.call(initial)
    expect(result.halted?).to be(false)
    expect(result.object).to eq('Mr. John')
    expect(result.payload[:age]).to eq(40)
  end

  specify 'invalid payload' do
    initial = Bridger::Result::Success.build(payload: { name: '' })
    result = action.call(initial)
    expect(result.halted?).to be(true)
    expect(result.errors['$.name']).not_to be_empty
    expect(result.object).to be_nil
  end

  context 'with custom pipeline' do
    subject(:action) do
      Class.new(Bridger::Action) do
        payload_schema do
          field(:age).type(:integer).default(40)
          field(:name).type(:string).present
        end

        def pipeline
          Bridger::Pipeline.new do |pl|
            pl.step method(:before_schemas)
            pl.step validate_schemas
            pl.step method(:after_schemas)
            pl.step! method(:always_run)
          end
        end

        def before_schemas(result)
          result.continue do |r|
            r[:before] = true
          end
        end

        def after_schemas(result)
          result.continue do |r|
            r[:after] = true
          end
        end

        def always_run(result)
          result.copy do |r|
            r[:always] = true
          end
        end
      end
    end

    specify 'valid payload' do
      initial = Bridger::Result::Success.build(payload: { name: 'John' })
      result = action.call(initial)
      expect(result.halted?).to be(false)
      expect(result[:before]).to be(true)
      expect(result[:after]).to be(true)
      expect(result[:always]).to be(true)
      expect(result.payload[:age]).to eq(40)
    end

    specify 'invalid payload' do
      initial = Bridger::Result::Success.build(payload: { name: '' })
      result = action.call(initial)
      expect(result.halted?).to be(true)
      expect(result[:before]).to be(true)
      expect(result[:after]).to be_nil
      expect(result[:always]).to be(true)
      expect(result.errors['$.name']).not_to be_empty
    end
  end
end
