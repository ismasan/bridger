require "spec_helper"
require "bridger/service"

RSpec.describe Bridger::Service do
  Action = Class.new do
    def initialize(result)
      @result = result
    end

    def call(query: {}, payload: {}, auth:)
      @result
    end
  end

  Serializer = Class.new do
    def initialize(data, h:, auth:)
      @data = data
    end

    def to_hash
      @data
    end
  end

  it "registers endpoints" do
    auth = double('Auth', authorize!: true, shop_ids: [1,2,3])

    points = described_class.new.build do
      authorize "btc.account.shops.mine" do |scope, auth, params|
        auth.shop_ids.include? params[:shop_id].to_i
      end

      endpoint(:root, :get, "/?",
        title: "API root",
        scope: "btc.me",
        action: Action.new(foo: 'bar'),
        serializer: Serializer
      )

      endpoint(:shop, :get, "/shops/:id",
        title: "Shop details",
        scope: "btc.account.shops.mine.list",
        action: Action.new(bar: 'foo'),
        serializer: Serializer
      )
    end

    # it looks up
    endpoint = points[:root]
    expect(endpoint).to be_a Bridger::Endpoint
    expect(endpoint.path).to eq '/?'
    expect(endpoint.verb).to eq :get

    helper = double('Helper', params: {shop_id: 2})
    result = endpoint.run!(payload: {}, auth: auth, helper: helper)
    expect(result.to_hash).to eq(foo: 'bar')
  end

  it 'passes instrumenter to endpoints' do
    instrumenter = double('SomeInstrumenter', instrument: {})
    expect(Bridger::Endpoint).to receive(:new).with(hash_including(instrumenter: instrumenter)).and_call_original

    srv = described_class.new
    srv.instrumenter instrumenter
    srv.endpoint(:shop, :get, '/shops/:id',
      title: "API root",
      scope: "btc.me",
      action: Action.new(foo: 'bar'),
      serializer: Serializer
    )
  end

  it 'checks that instrumenter implements #instrument' do
    srv = described_class.new

    expect {
      srv.instrumenter 'nope!'
    }.to raise_error(ArgumentError)
  end
end
