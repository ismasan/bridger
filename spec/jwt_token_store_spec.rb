# frozen_string_literal: true

require 'spec_helper'
require 'bridger/jwt_token_store'
require 'bridger/test_helpers'

RSpec.describe Bridger::JWTTokenStore do
  include Bridger::TestHelpers

  describe "#set and #get" do
    let(:store) do
      described_class.new(
        test_private_key.public_key,
        pkey: test_private_key
      )
    end

    it "encodes claims into JWT token" do
      token = store.set(
        uid: 111,
        scopes: ['admin']
      )

      expect(token).to be_a String

      claims = store.get(token)
      expect(claims['uid']).to eq 111
      expect(claims['scopes']).to eq ['admin']
      expect(claims['exp']).not_to be_nil
    end

    it "accepts string keys" do
      store = described_class.new(test_private_key.public_key.to_s, pkey: test_private_key.to_s)
      token = store.set(uid: 111)
      claims = store.get(token)
      expect(claims['uid']).to eq 111
    end

    it "accepts #read able keys" do
      public_key = StringIO.new(test_private_key.public_key.to_s)
      store = described_class.new(public_key, pkey: test_private_key)
      token = store.set(uid: 111)
      claims = store.get(token)
      expect(claims['uid']).to eq 111
    end

    it "accepts RS512 keys" do
      store = described_class.new(
        test_private_key.public_key,
        pkey: test_private_key,
        algo: 'RS512'
      )
      token = store.set(uid: 111)
      claims = store.get(token)
      expect(claims['uid']).to eq 111
    end

    it "accepts HMAC key HS256" do
      store = described_class.new("somesecret", algo: 'HS256')
      token = store.set(uid: 111)
      claims = store.get(token)
      expect(claims['uid']).to eq 111
    end

    it "accepts HMAC key HS512" do
      store = described_class.new("somesecret", algo: 'HS512')
      token = store.set(uid: 111)
      claims = store.get(token)
      expect(claims['uid']).to eq 111
    end

    it "raises if invalid JWT" do
      expect{
        store.get('foobar')
      }.to raise_error Bridger::InvalidAccessTokenError
    end

    it "raises if expired JWT" do
      token = store.set(
        exp: Time.now.to_i - 2,
        uid: 111,
        scopes: ['admin']
      )

      expect{
        store.get(token)
      }.to raise_error Bridger::ExpiredAccessTokenError
    end
  end
end
