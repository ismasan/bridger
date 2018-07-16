require "spec_helper"
require "bridger/authorizers"

RSpec.describe Bridger::Authorizers do
  TREE = Bridger::Authorizers::Tree.new do
    t "btc" do
      t "account" do
        t "shops" do
          t "mine" do
            check do |scope, auth, params|
              auth.shop_ids.include? params[:shop_id].to_i
            end

            t "public" do
              check do |scope, auth, params|

              end
            end
          end
        end
      end
    end
  end

  it do
    auth = double("auth", shop_ids: [1, 2, 3])
    params = {shop_id: 2}

    expect(TREE.authorized?("btc", auth, params)).to be true
    expect(TREE.authorized?("btc.account", auth, params)).to be true
    expect(TREE.authorized?("btc.account.shops", auth, params)).to be true
    expect(TREE.authorized?("btc.account.shops".split('.'), auth, params)).to be true
    expect(TREE.authorized?("btc.account.shops.mine", auth, params)).to be true
    expect(TREE.authorized?("btc.account.shops.mine.show", auth, params)).to be true
    expect(TREE.authorized?("btc.account.shops.mine", auth, {shop_id: 10})).to be false
    expect(TREE.authorized?("btc.account.shops.mine.show", auth, {shop_id: 10})).to be false

    tree = Bridger::Authorizers::Tree.new
    tree.at("btc.account") do |auth, params|
      false
    end

    expect(tree.authorized?("btc", auth, params)).to be true
    expect(tree.authorized?("btc.foo", auth, params)).to be true
    expect(tree.authorized?("btc.account", auth, params)).to be false
    expect(tree.authorized?("btc.account.shops", auth, params)).to be false
  end
end
