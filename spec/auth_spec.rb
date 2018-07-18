require "spec_helper"
require "bridger/auth"

RSpec.describe Bridger::Auth do
  before :all do
    Bridger::Auth.config do |c|
      # Map scope aliases to what they actually mean
      c.aliases = {
        "god"    => ["btc"],
        "admin"  => ["btc.me", "btc.account.shops.mine"],
        "public" => ["btc.me"]
      }

      # Use this RSA public key to
      # verify JWT access tokens
      c.public_key = test_private_key.public_key
    end
  end

  describe ".parse" do
    it "parses token from header and extracts claims correctly" do
      token = token_generator.generate(
        uid: 123,
        sids: [11],
        aid: 12,
        scopes: ["admin"]
      )
      req = double('Request', env: {'HTTP_AUTHORIZATION' => "Bearer #{token}"})
      auth = described_class.parse(req)
      expect(auth.shop_ids).to eq [11]
      expect(auth.app_id).to eq 12
      expect(auth.user_id).to eq 123
      expect(auth.has_user?).to be true
      expect(auth.scopes.to_a).to eq ['btc.me', 'btc.account.shops.mine']
    end

    it "parses token from querystring if configured" do
      token = token_generator.generate(
        uid: 123,
        sids: [11],
        aid: 12,
        scopes: ["admin"]
      )
      req = double('Request', params: {'token' => token})
      config = Bridger::Auth::Config.new
      config.parse_from :query, :token
      config.public_key = test_private_key.public_key

      auth = described_class.parse(req, config)
      expect(auth.shop_ids).to eq [11]
      expect(auth.app_id).to eq 12
    end

    it "gets token claims from custom store, if configured" do
      req = double('Request', params: {'token' => 'foo'})
      config = Bridger::Auth::Config.new
      config.parse_from :query, :token
      config.token_store = {
        'foo' => {
          'uid' => 123,
          'sids' => [11],
          'aid' => 12,
          'scopes' => ["admin"]
        }
      }

      auth = described_class.parse(req, config)
      expect(auth.shop_ids).to eq [11]
      expect(auth.app_id).to eq 12
    end

    it "raises known exception if invalid token" do
      token = token_generator.generate(
        exp: Time.now.to_i - 10,
        uid: 123,
        sids: [11],
        aid: 12,
        scopes: ["admin"]
      )
      req = double('Request', env: {'HTTP_AUTHORIZATION' => "Bearer #{token}"})

      expect {
        described_class.parse(req)
      }.to raise_error Bridger::ExpiredAccessTokenError
    end
  end

  describe "#authorize!" do
    it "authorizes when scopes match" do
      token = token_generator.generate(
        uid: 123,
        sids: [11],
        aid: 12,
        scopes: ["a.b.c"]
      )
      req = double('Request', env: {'HTTP_AUTHORIZATION' => "Bearer #{token}"})

      authorizer = Bridger::Authorizers::Tree.new
      authorizer.at('a.b') do |s, auth, params|
        !params || params[:foo] != "bar"
      end

      auth = described_class.parse(req)

      expect(auth.authorize!('a.b.c', authorizer)).to be true
      expect(auth.authorize!('a.b.c.d', authorizer)).to be true
      expect {
        auth.authorize!('a.b', authorizer)
      }.to raise_error Bridger::InsufficientScopesError

      expect {
        auth.authorize!('a.b.c', authorizer, foo: "bar")
      }.to raise_error Bridger::ForbiddenAccessError
    end
  end
end
