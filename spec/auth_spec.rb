# frozen_string_literal: true

require "spec_helper"
require "bridger/auth"

RSpec.describe Bridger::Auth do
  before :all do
    @config = Bridger::Auth::Config.new
    @config.aliases = {
      "god"    => ["btc"],
      "admin"  => ["btc.me", "btc.account.shops.mine"],
      "public" => ["btc.me"]
    }
    @config.token_store = {}
    @token_store = @config.token_store
  end

  describe ".parse" do
    it "parses token from header and extracts claims correctly" do
      token = @token_store.set(
        uid: 123,
        sids: [11],
        aid: 12,
        scopes: ["admin"]
      )
      req = double('Request', env: {'HTTP_AUTHORIZATION' => "Bearer #{token}"})
      auth = described_class.parse(req, @config)
      expect(auth.claims['sids']).to eq [11]
      expect(auth.scopes.to_a).to eq ['btc.me', 'btc.account.shops.mine']
      expect(auth.access_token).to eq token
    end

    it "parses token from querystring if configured" do
      token = @token_store.set(uid: 123,)
      req = double('Request', params: {'token' => token})
      config = Bridger::Auth::Config.new
      config.parse_from :query, :token
      config.token_store = @token_store

      auth = described_class.parse(req, config)
      expect(auth.claims['uid']).to eq 123
    end

    it 'takes custom authenticator to extract access token from request' do
      token = @token_store.set(uid: 124,)
      req = double('Request', params: {'token' => token[0..2]}, env: {'TOKEN' => token[3..-1]})
      config = Bridger::Auth::Config.new
      config.authenticator ->(req) { req.params['token'] + req.env['TOKEN'] }
      config.token_store = @token_store

      auth = described_class.parse(req, config)
      expect(auth.claims['uid']).to eq 124
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
      expect(auth.claims['sids']).to eq [11]
      expect(auth.claims['aid']).to eq 12
    end

    it "raises known exception if invalid token" do
      req = double('Request', env: {'HTTP_AUTHORIZATION' => "Bearer foobar"})

      expect {
        described_class.parse(req, @config)
      }.to raise_error Bridger::InvalidAccessTokenError
    end
  end

  describe "#authorize!" do
    it "authorizes when scopes match" do
      token = @token_store.set(
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

      auth = described_class.parse(req, @config)

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
