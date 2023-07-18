# frozen_string_literal: true

require "spec_helper"
require 'bridger/scopes'

RSpec.describe Bridger::Scopes do
  describe Bridger::Scopes::Scope do
    it 'compares scopes' do
      more_specific_scope =  scope("btc.account.shops.mine.update")
      less_specific_scope =  scope("btc.account.shops.mine")
      different_scope =  scope("btc.foo.shops.mine")

      expect(more_specific_scope.can?(less_specific_scope)).to be false
      expect(less_specific_scope.can?(more_specific_scope)).to be true
      expect(less_specific_scope.can?(less_specific_scope)).to be true

      expect(more_specific_scope.can?(different_scope)).to be false
      expect(less_specific_scope.can?(different_scope)).to be false
      expect(different_scope.can?(less_specific_scope)).to be false
      expect(different_scope.can?(more_specific_scope)).to be false
      expect(first_one_wins('all.root', 'all.mobiles.root')).to be false
    end

    it 'allows wildcards' do
      expect(first_one_wins('a.*.c', 'a.b.c')).to be true
      expect(first_one_wins('a.*.c', 'a.b.z')).to be false
      expect(first_one_wins('a.*.c', 'a.z.c.e')).to be true
      expect(first_one_wins('a.*.c', 'a.z.*')).to be true
      expect(first_one_wins('a.*.c', 'a.z.*.x')).to be true
      expect(first_one_wins('a.*.c.*', 'a.z.c')).to be false
      expect(first_one_wins('a.*.c.*', 'a.b.c.d')).to be true
      expect(first_one_wins('a.*.c.*', 'a.b.c.*')).to be true
      expect(first_one_wins('a.*.c.*', 'a.*.c.*')).to be true
    end

    it 'allows array values' do
      expect(first_one_wins('accounts:1,2,3', 'accounts:2')).to be true
      expect(first_one_wins('accounts:2', 'accounts:1,2,3')).to be true
      expect(first_one_wins('accounts:1,2,3', 'accounts:4')).to be false
      expect(first_one_wins('accounts:1,2,3', 'accounts')).to be false
    end

    specify '#expand' do
      expect(scope('a.b:<foo_id>.c').expand(foo_id: 1).to_s).to eq('a.b:1.c')
      expect(scope('a.b:<foo_id>.c').expand(foo_id: [1, 2]).to_s).to eq('a.b:1,2.c')
    end

    specify 'expanding with array values and comparing' do
      endpoint_scope = scope('api.accounts:<account_id>.shops:<shop_id>.contacts:*.read')
      token_scope = scope('api.accounts:<own_account>.shops:<own_shops>.contacts')

      endpoint_scope = endpoint_scope.expand(account_id: 111, shop_id: 222)
      token_scope = token_scope.expand(own_account: 111, own_shops: [222, 333])
      expect(token_scope >= endpoint_scope).to be true
      expect(token_scope == endpoint_scope).to be false
      expect(token_scope > endpoint_scope).to be true
    end

    specify do
      product_scope = scope('api.accounts:111.shops:222.products:333')
      token_scope =   scope('api.accounts:111.shops:222')
      expect(token_scope > product_scope).to be true
    end
  end

  describe Bridger::Scopes::Aliases do
    it 'maps aliases' do
      aliases = described_class.new(
        'admin' => %w[btc.me btc.account.shops.mine],
        'public' => %w[btc.me btc.shops.list.public]
      )

      scopes = aliases.map(%w[admin btc.foo.bar])
      expect(scopes).to be_a(Bridger::Scopes)
      expect(scopes).to match_array %w[btc.me btc.account.shops.mine btc.foo.bar]
    end

    it 'expands aliases preserving original scopes' do
      aliases = described_class.new(
        'admin' => %w[btc.me btc.account.shops.mine],
        'public' => %w[btc.me btc.shops.list.public]
      )

      scopes = aliases.expand(%w[admin btc.foo.bar])
      expect(scopes.to_a).to match_array %w[admin btc.me btc.account.shops.mine]
      expect(aliases.expand(%w[nope]).any?).to be(false)
    end

    it 'works with scope trees' do
      scopes = Bridger::Scopes::Tree.new('api') do
        admin
        me
        products do
          read
          write
        end
      end

      aliases = described_class.new(
        scopes.api.admin => [scopes.api.me, scopes.api.products],
        'guest' => [scopes.api.me]
      )

      expect(aliases.map(%w[api.admin])).to match_array %w[api.me api.products]
      expect(aliases.map(%w[guest])).to match_array %w[api.me]
      expect(aliases.map(%w[api.me])).to match_array %w[api.me]
    end
  end

  it "compares" do
    expect(described_class.wrap(['api']) > described_class.wrap(['api.me'])).to be true
    expect(described_class.wrap(:api) > described_class.wrap(['api.me'])).to be true
    expect(described_class.wrap(['foo', 'api']) > described_class.wrap(['api.me'])).to be true
    expect(described_class.wrap(['foo', 'api']) > described_class.wrap(['api', 'api.me'])).to be true
    expect(described_class.wrap(['api.users']) > described_class.wrap(['api', 'api.me'])).to be false
    expect(described_class.wrap(['api.users']) > described_class.wrap(['api', 'api.me', 'api.users.create'])).to be false
  end

  describe "#resolve" do
    it "finds the shallowest matching scope, or nil" do
      scopes = described_class.new(%w[btc.me btc.account.shops.mine btc.account btc.shops.list])
      expect(scopes.resolve('btc')).to be nil
      expect(scopes.resolve('btc.me').to_s).to eql 'btc.me'
      expect(scopes.resolve('btc.account').to_s).to eq 'btc.account'
      expect(scopes.resolve('btc.account.update').to_s).to eq 'btc.account'
      expect(scopes.resolve('btc.account.shops.mine').to_s).to eq 'btc.account'
      expect(scopes.resolve('btc.account.shops.mine.list.foo').to_s).to eq 'btc.account'
      expect(scopes.resolve('btc.shops.update')).to be nil
      expect(scopes.resolve('btc.shops.list').to_s).to eq 'btc.shops.list'
      expect(scopes.resolve('btc.shops.list.show.foo').to_s).to eq 'btc.shops.list'
    end
  end

  describe "#can?" do
    it "is true if any scope is authorized" do
      user_scopes = described_class.new(["btc.account", "btc.account.assets.mine.update"])
      required_scopes = described_class.new(["btc.account.shops", "btc.account.users"])

      expect(user_scopes.can?(required_scopes)).to be true
      expect(required_scopes.can?(user_scopes)).to be false
      expect(user_scopes.can?('btc.account.assets.mine.create')).to be true

      user_scopes = described_class.new(["admin"])
      required_scopes = described_class.new(["btc.me", "admin"])

      expect(user_scopes.can?(required_scopes)).to be true
    end
  end

  describe "#to_a" do
    it "is an array of strings" do
      user_scopes = described_class.new(["aa.aa", "bb.bb"])
      expect(user_scopes.to_a).to eq ["aa.aa", "bb.bb"]
    end
  end

  private

  def scope(exp)
    described_class.wrap(exp)
  end

  def first_one_wins(exp1, exp2)
    scope(exp1).can?(scope(exp2))
  end
end
