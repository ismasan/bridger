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
      c.public_key_path = test_key_path('public_key.rsa.pub')
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

      auth = described_class.parse("Bearer #{token}")
      expect(auth.shop_ids).to eq [11]
      expect(auth.app_id).to eq 12
      expect(auth.user_id).to eq 123
      expect(auth.has_user?).to be true
      expect(auth.scopes.to_a).to eq ['btc.me', 'btc.account.shops.mine']
    end

    it "raises known exception if invalid token" do
      token = token_generator.generate(
        exp: Time.now.to_i - 10,
        uid: 123,
        sids: [11],
        aid: 12,
        scopes: ["admin"]
      )

      expect {
        described_class.parse("Bearer #{token}")
      }.to raise_error Bridger::Auth::InvalidAccessTokenError
    end
  end

  def test_key_path(str)
    File.join(
      File.dirname(__FILE__),
      "support",
      "test_credentials",
      str
    )
  end

  def token_generator
    @token_generator ||= Bridger::TokenGenerator.new(
      test_key_path('private_key.rsa')
    )
  end
end
