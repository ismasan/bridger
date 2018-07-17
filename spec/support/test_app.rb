require 'sinatra/base'
require 'sinatra/bridger'

# Bridger::Auth.config do |c|
#   # Map scope aliases to what they actually mean
#   c.aliases = {
#     "god"    => ["btc"],
#     "admin"  => ["btc.me", "btc.account.shops.mine"],
#     "public" => ["btc.me"]
#   }

#   # Use this RSA public key to
#   # verify JWT access tokens
#   # c.public_key = File.join(
#   #   File.dirname(__FILE__),
#   #   "test_credentials",
#   #   "public_key.rsa.pub"
#   # )
# end

RootModel = Struct.new(:app_name)
ShopModel = Struct.new(:url, :name)

class RootAction < Bridger::Action
  private
  def run!
    RootModel.new("ACME")
  end
end

class ShopAction < Bridger::Action
  private
  def run!
    ShopModel.new('acme.bootic.net', 'ACME')
  end
end

class ShopsAction < Bridger::Action
  schema do
    field(:q).type(:string)
    field(:page).type(:integer)
  end

  private
  def run!
    [
      ShopModel.new('acme.bootic.net', 'ACME'),
      ShopModel.new('www.bootic.net', 'Bootic'),
    ]
  end
end

class RootSerializer < Bridger::Serializer
  schema do
    rel :shop, always: true

    link("btc:docs",
     href: "https://developers.bootic.net",
     type: "text/html",
     title: "API documentation"
    )
    link("btc:schemas", href: url("/rels"))

    self_link
    property :app_name, item.app_name
  end
end

class ShopSerializer < Bridger::Serializer
  schema do
    rel :root
    self_link
    property :url, item.url
    property :name, item.name
  end
end

class ShopsSerializer < Bridger::Serializer
  schema do
    rel :root
    self_link
    items item, ShopSerializer
  end
end

Bridger::Endpoints.instance.build do
  authorize "btc.account.shops.mine" do |scope, auth, params|
    auth.shop_ids.include? params[:shop_id].to_i
  end

  endpoint(:root, :get, "/?",
    title: "API root",
    scope: "btc.me",
    action: RootAction,
    serializer: RootSerializer,
  )

  endpoint(:shop, :get, "/shops/:shop_id",
    title: "Shop details",
    scope: "btc.account.shops.mine.list",
    action: ShopAction,
    serializer: ShopSerializer,
  )

  endpoint(:shops, :get, "/shops",
    title: "Shop details",
    scope: "btc.account.shops.mine.list",
    action: ShopsAction,
    serializer: ShopsSerializer,
  )
end

class TestApp < Sinatra::Base
  register Sinatra::Bridger
  bridge Bridger::Endpoints.instance, schemas: true
end
