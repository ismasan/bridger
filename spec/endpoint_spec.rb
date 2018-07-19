require "spec_helper"
require "bridger/endpoint"

RSpec.describe Bridger::Endpoint do
  let(:authorizer) { double('Authorizer') }
  let(:action) { double('Action') }
  let(:serializer) { double('Serializer') }

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

  it "runs action" do
    endpoint = described_class.new(
      name: 'create_product',
      verb: :post,
      path: '/v1/shops/{shop_id}/products',
      title: 'Create products',
      scope: 'a.b.c',
      authorizer: authorizer,
      action: action,
      serializer: serializer
    )

    auth = double('Auth')
    params = {foo: 'bar'}
    helper = double('Helper', params: params)
    presenter = double('Presenter')

    expect(auth).to receive(:authorize!).with(endpoint.scope, authorizer, params).and_return true
    expect(action).to receive(:run!).with(payload: {p1: 1}, auth: auth).and_return presenter
    expect(serializer).to receive(:new).with(presenter, h: helper, auth: auth).and_return({out: 1})

    data = endpoint.run!(payload: {p1: 1}, auth: auth, helper: helper)
    expect(data).to eq({out: 1})

    # builds relation
    rel = endpoint.build_rel(shop_id: 123, foo: 'b')
    expect(rel).to be_a Bridger::Rel
    expect(rel.path).to eq '/v1/shops/123/products'
    expect(rel.title).to eq 'Create products'
    expect(rel.verb).to eq :post
  end

  it "#authorized?" do
    endpoint = described_class.new(
      name: 'create_product',
      verb: :post,
      path: '/v1/shops/{shop_id}/products',
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
end
