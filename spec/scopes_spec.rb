require "spec_helper"
require 'bridger/scopes'

RSpec.describe Bridger::Scopes do
  describe Bridger::Scopes::Scope do
    it 'compares scopes' do
      more_specific_scope =  described_class.new("btc.account.shops.mine.update")
      less_specific_scope =  described_class.new("btc.account.shops.mine")
      different_scope =  described_class.new("btc.foo.shops.mine")

      expect(more_specific_scope.can?(less_specific_scope)).to be false
      expect(less_specific_scope.can?(more_specific_scope)).to be true
      expect(less_specific_scope.can?(less_specific_scope)).to be true

      expect(more_specific_scope.can?(different_scope)).to be false
      expect(less_specific_scope.can?(different_scope)).to be false
      expect(different_scope.can?(less_specific_scope)).to be false
      expect(different_scope.can?(more_specific_scope)).to be false
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
  end

  describe Bridger::Scopes::Aliases do
    it "maps aliases" do
      aliases = described_class.new(
        "admin" => ["btc.me", "btc.account.shops.mine"],
        "public" => ["btc.me", "btc.shops.list.public"]
      )

      scopes = aliases.map(["admin", "btc.foo.bar"])
      expect(scopes).to match_array ["btc.me", "btc.account.shops.mine", "btc.foo.bar"]
    end
  end

  it "compares" do
    expect(described_class.wrap(['api']) > described_class.wrap(['api.me'])).to be true
    expect(described_class.wrap(['foo', 'api']) > described_class.wrap(['api.me'])).to be true
    expect(described_class.wrap(['foo', 'api']) > described_class.wrap(['api', 'api.me'])).to be true
    expect(described_class.wrap(['api.users']) > described_class.wrap(['api', 'api.me'])).to be false
    expect(described_class.wrap(['api.users']) > described_class.wrap(['api', 'api.me', 'api.users.create'])).to be false
  end

  describe "#resolve" do
    it "finds the shallowest matching scope, or nil" do
      scopes = described_class.new(["btc.me", "btc.account.shops.mine", "btc.account", "btc.shops.list"])
      expect(scopes.resolve("btc")).to be nil
      expect(scopes.resolve("btc.me").to_s).to eql "btc.me"
      expect(scopes.resolve("btc.account").to_s).to eq "btc.account"
      expect(scopes.resolve("btc.account.update").to_s).to eq "btc.account"
      expect(scopes.resolve("btc.account.shops.mine").to_s).to eq "btc.account"
      expect(scopes.resolve("btc.account.shops.mine.list.foo").to_s).to eq "btc.account"
      expect(scopes.resolve("btc.shops.update")).to be nil
      expect(scopes.resolve("btc.shops.list").to_s).to eq "btc.shops.list"
      expect(scopes.resolve("btc.shops.list.show.foo").to_s).to eq "btc.shops.list"
    end
  end

  describe "#can?" do
    it "is true if any scope is authorized" do
      user_scopes = described_class.new(["btc.account", "btc.account.assets.mine.update"])
      required_scopes = described_class.new(["btc.account.shops", "btc.account.users"])

      expect(user_scopes.can?(required_scopes)).to be true
      expect(required_scopes.can?(user_scopes)).to be false

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
    described_class.new(exp)
  end

  def first_one_wins(exp1, exp2)
    scope(exp1).can?(scope(exp2))
  end

end
