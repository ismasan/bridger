require 'spec_helper'
require 'bridger/test_helpers'
require_relative './support/test_api'

RSpec.describe 'Sinatra apps' do
  include Bridger::TestHelpers

  def app
    TestApi
  end

  before :all do
    Bridger::Auth.config do |c|
      c.aliases = {
        "god"    => ["btc"],
        "admin"  => ["btc.me", "btc.account.shops.mine"],
        "public" => ["btc.me"]
      }

      c.public_key = test_private_key.public_key
    end
  end

  it 'works' do
    authorize!(
      uid: 123,
      sids: [11],
      aid: 11,
      scopes: ["admin"]
    )

    expect(root.app_name).to eq 'ACME'
    shop = root.shop(shop_id: 11)
    expect(shop.url).to eq 'acme.bootic.net'
    expect(shop.name).to eq 'ACME'

    shop = shop.self
    expect(shop.url).to eq 'acme.bootic.net'

    schemas = root.schemas
    expect(schemas.map(&:rel).sort).to eq ['root', 'shop', 'shops']
  end
end
