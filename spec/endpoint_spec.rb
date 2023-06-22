# frozen_string_literal: true

require "spec_helper"
require "bridger/endpoint"
require "bridger/action"

RSpec.describe Bridger::Endpoint do
  let(:authorizer) { double('Authorizer') }
  let(:action) do
    Class.new(Bridger::Action) do
      query_schema do
        field(:product_id).type(:string).present
        field(:q).type(:string)
      end

      # class name
      def self.name
        'SomeAction'
      end
    end
  end

  let(:serializer) do
    Class.new(Bridger::Serializer) do
      def self.name
        'SomeSerializer'
      end
    end
  end

  it "has readers" do
    endpoint = described_class.new(
      name: 'create_product',
      verb: :post,
      path: '/v1/products',
      title: 'Create products',
      scope: 'a.b.c',
      authorizer: authorizer,
      action: action,
      serializer: serializer
    )

    expect(endpoint.path).to eq '/v1/products'
    expect(endpoint.verb).to eq :post
    expect(endpoint.name).to eq "create_product"
    expect(endpoint.scope.to_s).to eq 'a.b.c'
    expect(endpoint.action).to eq action
    expect(endpoint.serializer).to eq serializer
  end

  it 'it accepts #to_scope interface' do
    scope_class = Data.define(:scope) do
      def to_scope
        Bridger::Scopes::Scope.new(scope)
      end
    end

    endpoint = described_class.new(
      name: 'create_product',
      verb: :post,
      path: '/v1/products',
      title: 'Create products',
      scope: scope_class.new(scope: 'a.b.c'),
      authorizer: authorizer,
      action: action,
    )

    expect(endpoint.scope.to_s).to eq 'a.b.c'
  end

  describe '#run' do
    let(:auth) { double('Auth', authorize!: true) }
    let(:presenter) { double('Presenter') }

    before do
      allow(action).to receive(:call).and_return(presenter)
    end

    it "runs action" do
      endpoint = described_class.new(
        name: 'create_product',
        verb: :post,
        path: '/v1/shops/:shop_id/products',
        title: 'Create products',
        scope: 'a.b.c',
        authorizer: authorizer,
        action: action,
        serializer: serializer
      )

      params = {foo: 'bar'}
      helper = double('Helper', params: params)

      expect(auth).to receive(:authorize!).with(endpoint.scope, authorizer, params).and_return true
      expect(action).to receive(:call).with(query: {}, payload: {p1: 1}, auth: auth).and_return presenter
      expect(serializer).to receive(:new).with(presenter, {h: helper, auth: auth}).and_return({out: 1})

      data = endpoint.run!(payload: {p1: 1}, auth: auth, helper: helper)
      expect(data).to eq({out: 1})
    end

    it 'instruments run' do
      helper = double('Helper', params: {})
      allow(Bridger::NullInstrumenter).to receive(:instrument).and_call_original

      endpoint = described_class.new(
        name: 'products',
        verb: :get,
        path: '/v1/products/:product_id',
        title: 'list products',
        scope: 'a.b.c',
        authorizer: authorizer,
        action: action,
        serializer: serializer,
        instrumenter: Bridger::NullInstrumenter
      )

      expect(Bridger::NullInstrumenter).to receive(:instrument) do |name, payload, blk|
        expect(name).to eq('bridger.action')
        expect(payload[:class_name]).to eq('SomeAction')
        expect(payload[:verb]).to eq(:get)
        expect(payload[:path]).to eq(endpoint.path)
        expect(payload[:name]).to eq('products')
        expect(payload[:title]).to eq('list products')
      end

      expect(Bridger::NullInstrumenter).to receive(:instrument) do |name, payload, blk|
        expect(name).to eq('bridger.serializer')
        expect(payload[:class_name]).to eq('SomeSerializer')
      end

      endpoint.run!(payload: {p1: 1}, auth: auth, helper: helper)
    end
  end

  it "builds relation" do
    endpoint = described_class.new(
      name: 'products',
      verb: :get,
      path: '/v1/products/:product_id',
      title: 'list products',
      scope: 'a.b.c',
      authorizer: authorizer,
      action: action,
      serializer: serializer
    )

    # builds relation
    rel = endpoint.build_rel(product_id: 123, foo: 'b')
    expect(rel).to be_a Bridger::Rel
    expect(rel.path).to eq '/v1/products/123{?q}'
    expect(rel.title).to eq 'list products'
    expect(rel.verb).to eq :get
  end

  describe '#authorized?' do
    it "delegates to auth and authorizer" do
      endpoint = described_class.new(
        name: 'create_product',
        verb: :post,
        path: '/v1/shops/:shop_id/products',
        title: 'Create products',
        scope: 'a.b.c',
        authorizer: authorizer,
        action: action,
        serializer: serializer
      )

      auth = double('Auth')
      expect(auth).to receive(:authorized?).with(endpoint.scope).and_return true
      expect(authorizer).to receive(:authorized?).with(endpoint.scope.to_a, auth, {}).and_return true
      expect(endpoint.authorized?(auth, {})).to be true
    end

    it 'returns true if no scope/authorization scheme setup' do
      endpoint = described_class.new(
        name: 'create_product',
        verb: :post,
        path: '/v1/shops/:shop_id/products',
        title: 'Create products',
        scope: nil,
        authorizer: authorizer,
        action: action,
        serializer: serializer
      )

      auth = double('Auth')
      expect(endpoint.authorized?(auth, {})).to be true
    end
  end
end
