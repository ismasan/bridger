require 'rack/test'
require 'bridger/test_helpers'

RSpec.shared_examples_for 'a REST API exposing a Bridger service' do
  include Bridger::TestHelpers
  include Rack::Test::Methods

  before :all do
    USERS.clear
    Bridger::Auth.config do |c|
      c.parse_from :header, 'HTTP_AUTHORIZATION'
      c.token_store = {}
      c.logger = Logger.new(STDOUT)
    end
  end

  context '404s' do
    it 'does not add X-Cascade header' do
      authorize!(
        uid: 123,
        sids: [11],
        aid: 11,
        scopes: ["api"]
      )

      resp = get('/foo/bar')
      expect(resp.headers['X-Cascade']).not_to eq('pass')
      expect(resp.status).to eq 404
    end
  end

  context 'with full scope' do
    it 'lists all links in root' do
      authorize!(
        uid: 123,
        sids: [11],
        aid: 11,
        scopes: ["api"]
      )

      expect_link(root, :status)
      expect_link(root, :user)
      expect_link(root, :users)
      expect_link(root, :create_user)
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

  it 'only shows allowed links' do
    authorize!(
      uid: 123,
      sids: [11],
      aid: 11,
      scopes: ["api.me"]
    )

    expect(root.rels.key?(:user)).to be false
    expect(root.rels.key?(:create_user)).to be false
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

  it "lists user things with links with added parameters" do
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

    things = user.user_things
    link = things.rels[:next]
    expect(link.href).to match /page=2/
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

  it "exposes public endpoints too" do
    rel = BooticClient::Relation.new({
      'href' => 'http://example.org/status'
    }, client)
    status = rel.run
    expect(status.ok).to be true
  end

  it "exposes schemas" do
    authorize!(
      uid: 123,
      sids: [11],
      aid: 11,
      scopes: ["api.me"]
    )
    schemas = root.schemas
    expect(schemas.map(&:rel).sort).to eq %w(create_user delete_user root schema schemas status user user_things users)
    schemas.first.tap do |sc|
      expect(sc.rel).to eq 'root'
      expect(sc.title).to eq 'API root'
      expect(sc.verb).to eq 'get'
      expect(sc.scope).to eq 'api.me'
      expect(sc.templated).to be false
      expect(sc.href).to eq 'http://example.org/'
    end
    item = schemas.items.find{|i| i.rel == 'users' }
    item.self.tap do |sc|
      expect(sc.query_schema.type).to eq 'object'
      expect(sc.query_schema.to_hash['properties']['q']['type']).to eq 'string'
      expect(sc.has?(:payload_schema)).to be true
    end
  end

  private

  def expect_link(entity, rel_name)
    rel = entity.rels[rel_name]
    expect(rel).to be_a BooticClient::Relation
  end
end
