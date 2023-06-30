# frozen_string_literal: true

# A simple users repository. You would use some ORM or database layer (ActiveRecord, Sequel, etc)
USERS = {}
# The models
User = Struct.new(:id, :name, :age)
Thing = Struct.new(:name)

# Actions are the things that your API can do
# they define parameter schemas that will be used to validate user input before they hit the model layer.
# their `#run!` method returns a data object (ex. a model) then passed to the serializer

class CreateUser < Bridger::Action
  payload_schema do
    field(:name).type(:string).required
    field(:age).type(:integer).required
  end

  def self.call(result)
    id = SecureRandom.uuid
    user = USERS[id] = User.new(
      id,
      result.payload[:name],
      result.payload[:age]
    )

    result.continue do |r|
      r[:user] = user
    end
  end
end

class ShowUser < Bridger::Action
  query_schema do
    field(:user_id).type(:string).required
  end

  def self.call(result)
    user = USERS.fetch(result.query[:user_id])
    result.continue do |r|
      r[:user] = user
    end
  end
end

class ListUserThings < Bridger::Action
  query_schema do
    field(:user_id).type(:string).required
    field(:page).type(:integer).default(1)
  end

  def self.call(result)
    things = [
      Thing.new("a"),
      Thing.new("b"),
    ]
    result.continue do |r|
      r[:things] = things
    end
  end
end

class DeleteUser < Bridger::Action
  query_schema do
    field(:user_id).type(:string).required
  end

  def self.call(result)
    USERS.delete(result.query[:user_id])
    result.continue do |r|
      r.response.status = 204
    end
  end
end

class ListUsers < Bridger::Action
  query_schema do
    field(:q).type(:string)
    field(:email).type(:string).declared.policy(:format, /@/, 'must be an email')
  end

  def self.call(result)
    users = USERS.values.sort_by(&:name)
    result.continue do |r|
      r[:users] = users
    end
  end
end

class ShowStatus < Bridger::Action
  def self.call(result)
    result.continue(data: { ok: true })
  end
end

# Serializers turn the result of actions into JSON structures
class RootSerializer < Bridger::Serializer
  schema do
    rel_directory

    link("btc:schemas", href: url("/schemas"))

    link("btc:docs",
         href: "https://developers.bootic.net",
         type: "text/html",
         title: "API documentation"
        )

    property :welcome, "Welcome to this API"
  end
end

class UserSerializer < Bridger::Serializer
  schema do
    rel :user, as: 'self', user_id: item[:user].id
    rel :delete_user, user_id: item[:user].id
    rel :user_things, user_id: item[:user].id
    rel :root

    property :id, item[:user].id
    property :name, item[:user].name
    property :age, item[:user].age
  end
end

class UserThingsSerializer < Bridger::Serializer
  schema do
    rel :root
    current_rel as: :next, page: 2

    items item[:things] do |thing, s|
      s.property :name, thing.name
    end
  end
end

class UsersSerializer < Bridger::Serializer
  schema do
    rel :user
    rel :root

    # TODO: fix this
    # top level serializers expect #item to be a Result
    # but then we can't use the same serializer nested in another.
    items item[:users].map { |u| { user: u} }, UserSerializer
  end
end

class StatusSerializer < Bridger::Serializer
  schema do
    property :ok, true
  end
end

# Initialize an in-memory access token store with a few test tokens
# so we can try it out in the browser, ex `/?access_token=me`
TOKEN_STORE = {
  'me' => {
    'scopes' => ['btc.me'],
    'aid' => 1,
    'sids' => [11]
  },
  'god' => {
    'scopes' => ['btc'],
    'aid' => 1,
    'sids' => [11]
  },
}

# configure this app to take access tokens from querystring
# note that we change this in specs to use the Authorization header
Bridger::Auth.config do |c|
  c.parse_from :query, :access_token
  c.token_store = TOKEN_STORE
end

SCOPES = Bridger::Scopes::Tree.new('api') do
  me
  users do
    list
    create
    delete
  end
end

# Your API's endpoints. Each combines an action, serializer, some metadata and a permissions scope.
Bridger::Service.instance.build do
  endpoint(:root, :get, "/",
    title: "API root",
    scope: SCOPES.api.me,
    serializer: RootSerializer,
  )

  endpoint(:users, :get, "/users",
    title: "List users",
    scope: SCOPES.api.users.list,
    action: ListUsers,
    serializer: UsersSerializer,
  )

  endpoint(:user, :get, "/users/:user_id",
    title: "User details",
    scope: SCOPES.api.users.list,
    action: ShowUser,
    serializer: UserSerializer,
  )

  endpoint(:user_things, :get, "/users/:user_id/things",
    title: "User things",
    scope: SCOPES.api.users.list,
    action: ListUserThings,
    serializer: UserThingsSerializer,
  )

  endpoint(:create_user, :post, "/users",
    title: "Create a new user",
    scope: SCOPES.api.users.create,
    action: CreateUser,
    serializer: UserSerializer,
  )

  endpoint(:delete_user, :delete, "/users/:user_id",
    title: "Delete user",
    scope: SCOPES.api.users.delete,
    action: DeleteUser,
    serializer: nil,
  )

  endpoint(:status, :get, "/status",
    title: "service status",
    action: ShowStatus,
    serializer: StatusSerializer,
    scope: nil,
  )

  schema_endpoints(path: '/schemas')
end

