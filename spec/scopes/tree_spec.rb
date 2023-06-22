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

  specify 'defining unique segments at the top' do
    tree = described_class.new('bootic') do |bootic|
      api = 'api'
      products = 'products'
      orders = 'orders'
      own = 'own'
      all = 'all'
      read = 'read'

      bootic > api > products > own > read
      bootic > api > products > all > read
      bootic > api > orders > own > read
    end

    expect(tree.bootic.api.products.own.read.to_s).to eq('bootic.api.products.own.read')
    expect(tree.bootic.api.products.*.read.to_s).to eq('bootic.api.products.*.read')
  end

  specify 'block notation with node argument' do
    tree = described_class.new('bootic') do |bootic|
      bootic.api.products do |n|
        n.own do |n|
          n.read
          n.write
          n > 'list'
        end

        n.all.read
      end
    end

    expect(tree.bootic.api.products.own.read.to_s).to eq('bootic.api.products.own.read')
    expect(tree.bootic.api.products.own.write.to_s).to eq('bootic.api.products.own.write')
    expect(tree.bootic.api.products.own.list.to_s).to eq('bootic.api.products.own.list')
    expect(tree.bootic.api.products.own.to_s).to eq('bootic.api.products.own')
    expect(tree.bootic.api.products.all.read.to_s).to eq('bootic.api.products.all.read')
  end

  specify 'block notation without node argument' do
    tree = described_class.new('bootic') do
      api.products do
        own do
          read
          write
        end

        all.read
      end
    end

    expect(tree.bootic.api.products.own.read.to_s).to eq('bootic.api.products.own.read')
    expect(tree.bootic.api.products.own.write.to_s).to eq('bootic.api.products.own.write')
    expect(tree.bootic.api.products.own.to_s).to eq('bootic.api.products.own')
    expect(tree.bootic.api.products.all.read.to_s).to eq('bootic.api.products.all.read')
  end
end
