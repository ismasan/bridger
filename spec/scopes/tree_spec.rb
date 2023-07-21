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

    expect(tree.bootic.respond_to?(:inspect)).to be(true)
    expect(tree.bootic.respond_to?(:to_scope)).to be(true)
    expect(tree.bootic.api.products.own.read.to_s).to eq('bootic.api.products.own.read')
    expect(tree.bootic.api.products.own.to_s).to eq('bootic.api.products.own')
    expect(tree.bootic.api.products.to_s).to eq('bootic.api.products')
    expect(tree.bootic.api.products.*.read.to_s).to eq('bootic.api.products.*.read')
    expect(tree.bootic.api.products.*.read.to_a).to eq(%w[bootic api products * read])
    expect {
      tree.bootic.foo.products
    }.to raise_error(Bridger::Scopes::Tree::InvalidScopeHierarchyError)

    expect {
      tree.bootic.api.products.*.api
    }.to raise_error(Bridger::Scopes::Tree::InvalidScopeHierarchyError)

    scope = tree.bootic.api.products.*.read.to_scope
    expect(scope).to be_a(Bridger::Scopes::Scope)
    expect(scope.to_s).to eq('bootic.api.products.*.read')
  end

  specify '* allows intersection of possible children' do
    tree = described_class.new('bootic') do |bootic|
      bootic.api.products.own.read
      bootic.api.products.own.delete
      bootic.api.products.all.read
      bootic.api.orders.own.read
    end

    # Wildcard nodes support the intersection of child nodes
    # In this case, bootic.api.products.own and bootic.api.products.all support read,
    # but only bootic.api.products.own supports delete
    expect {
      tree.bootic.api.products.*.delete
    }.to raise_error(Bridger::Scopes::Tree::InvalidScopeHierarchyError)
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

  specify 'wildcards' do
    tree = described_class.new('bootic') do
      api do
        products do
          _any do
            read
            write
          end
        end
      end
    end

    expect(tree.bootic.api.products.*.read.to_s).to eq('bootic.api.products.*.read')
    expect(tree.bootic.api.products._value('111').read.to_s).to eq('bootic.api.products.111.read')
    expect(tree.bootic.api.products._value([1, 2, 3]).read.to_s).to eq('bootic.api.products.(1,2,3).read')
  end

  specify do
    tree = Bridger::Scopes::Tree.new('bootic') do |bootic|
      integer = /^\d+$/

      bootic.api do
        accounts do
          _any('resource_account', 'own_account', integer) do
            shops do
              resource_shops do
                contacts do
                  _any do
                    read
                  end
                end

                products do
                  _any do
                    read
                  end
                end

                orders do
                  _any(integer) do
                    read
                  end
                end

                settings do
                  _any do
                    update
                  end
                end
              end
            end
          end
        end
      end
    end

    expect(tree.bootic.api.accounts.resource_account.shops.*.products.*.read.to_s).to eq('bootic.api.accounts.resource_account.shops.*.products.*.read')
    expect(tree.bootic.api.accounts.('123').shops.*.products.*.read.to_s).to eq('bootic.api.accounts.123.shops.*.products.*.read')
    expect(tree.bootic.api.accounts.own_account.shops.to_s).to eq('bootic.api.accounts.own_account.shops')
    expect(tree.bootic.api.accounts.resource_account.shops.*.orders.('123').read.to_s).to eq('bootic.api.accounts.resource_account.shops.*.orders.123.read')
    expect(tree.bootic.api.accounts.resource_account.shops.*.orders.(1,'2').read.to_s).to eq('bootic.api.accounts.resource_account.shops.*.orders.(1,2).read')
    expect(tree.bootic.api.accounts.resource_account.shops.*.orders.([1,'2']).read.to_s).to eq('bootic.api.accounts.resource_account.shops.*.orders.(1,2).read')
    expect(tree.bootic.api.accounts.*.shops.*.products.*.read.to_s).to eq('bootic.api.accounts.*.shops.*.products.*.read')

    # Invalid scope hierarchy (settings.*.read is not available in tree)
    expect {
      tree.bootic.api.accounts.*.shops.*.settings.*.read
    }.to raise_error(Bridger::Scopes::Tree::InvalidScopeHierarchyError)

    # Free value with invalid format
    expect {
      tree.bootic.api.accounts.resource_account.shops.*.orders._value('nope').read.to_s
    }.to raise_error(Bridger::Scopes::Tree::InvalidScopeHierarchyError)

    # Free value where none is declared
    expect {
      tree.bootic.api.accounts.resource_account.shops._value('11').orders.*.read.to_s
    }.to raise_error(Bridger::Scopes::Tree::InvalidScopeHierarchyError)

    # Invalid value for _any constraints
    expect {
      tree.bootic.api.accounts.('nope').shops
    }.to raise_error(Bridger::Scopes::Tree::InvalidScopeHierarchyError)
    # expect(tree.to_h).to eq({})
  end
end
