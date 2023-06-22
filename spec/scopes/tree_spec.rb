# frozen_string_literal: true

require "spec_helper"
require 'bridger/scopes/tree'

RSpec.describe Bridger::Scopes::Tree do
  specify 'declaring and accessing allowed scope hierarchies' do
    tree = described_class.new('bootic') do |bootic|
      bootic.api.products.own.read
      bootic.api.products.all.read
      bootic.api.orders.own.read
    end

    expect(tree.bootic.api.products.own.read.to_s).to eq('bootic.api.products.own.read')
    expect(tree.bootic.api.products.own.to_s).to eq('bootic.api.products.own')
    expect(tree.bootic.api.products.to_s).to eq('bootic.api.products')
    expect(tree.bootic.api.products.*.read.to_s).to eq('bootic.api.products.*.read')
    expect {
      tree.bootic.foo.products
    }.to raise_error(NoMethodError)

    expect {
      tree.bootic.api.products.*.api
    }.to raise_error(NoMethodError)

    scope = tree.bootic.api.products.*.read.to_scope
    expect(scope).to be_a(Bridger::Scopes::Scope)
    expect(scope.to_s).to eq('bootic.api.products.*.read')
  end
end