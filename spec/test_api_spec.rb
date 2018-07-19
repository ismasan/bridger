require 'spec_helper'
require 'bridger/test_helpers'
require_relative './support/test_api'

RSpec.describe 'Test Sinatra API' do
  include Bridger::TestHelpers

  def app
    TestAPI
  end

  before :all do
    Bridger::Auth.config do |c|
      c.parse_from :header, 'HTTP_AUTHORIZATION'
      c.token_store = {}
      c.logger = Logger.new(STDOUT)
    end
  end

  it "navigates to root" do
    authorize!(
      uid: 123,
      sids: [11],
      aid: 11,
      scopes: ["api.me"]
    )
    expect(root.welcome).to eq 'Welcome to this API'
  end

  it "creates and deletes user" do
    authorize!(
      uid: 123,
      sids: [11],
      aid: 11,
      scopes: ["api.me", "api.users"]
    )

    user = root.create_user(
      name: 'Ismael',
      age: 40
    )

    expect(user.name).to eq 'Ismael'
    expect(user.age).to eq 40
    expect(user.id).not_to be_nil

    user = user.self
    expect(user.name).to eq 'Ismael'

    user = root.user(user_id: user.id)
    expect(user.name).to eq 'Ismael'

    users = root.users
    expect(users.map(&:name)).to eq ['Ismael']

    user.delete_user(user_id: user.id)
    expect(root.users.map(&:name)).to eq []
  end

  it "responds with 404 if endpoint not found" do
    authorize!(
      uid: 123,
      sids: [11],
      aid: 11,
      scopes: ["api.me", "api.users"]
    )

    rel = BooticClient::Relation.new({'href' => 'http://example.com/fooobar/nope'}, client)
    expect{
      rel.run
    }.to raise_error BooticClient::NotFoundError
  end

  it "does not show links you're not allowed to use" do
    authorize!(
      uid: 123,
      sids: [11],
      aid: 11,
      scopes: ["api.me"]
    )

    expect(root.can?(:create_user)).to be false
  end

  it "exposes schemas" do
    authorize!(
      uid: 123,
      sids: [11],
      aid: 11,
      scopes: ["api.me"]
    )
    schemas = root.schemas
    expect(schemas.map(&:rel).sort).to eq ['create_user', 'delete_user', 'root', 'user', 'users']
    schemas.first.tap do |sc|
      expect(sc.rel).to eq 'root'
      expect(sc.title).to eq 'API root'
      expect(sc.verb).to eq 'get'
      expect(sc.scope).to eq 'api.me'
      expect(sc.templated).to be false
      expect(sc.href).to eq 'http://example.org/?'
      expect(sc.can?(:self)).to be true
    end
  end
end