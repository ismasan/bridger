require 'sinatra/bridger'
require 'sinatra/base'

# A simple users repository. You would use some ORM or database layer (ActiveRecord, Sequel, etc)
USERS = {}
# The models
User = Struct.new(:id, :name, :age)

# Actions are the things that your API can do
# they define parameter schemas that will be used to validate user input before they hit the model layer.
# their `#run!` method returns a data object (ex. a model) then passed to the serializer
class ShowRoot < Bridger::Action
  private
  def run!

  end
end

class CreateUser < Bridger::Action
  schema do
    field(:name).type(:string).required
    field(:age).type(:integer).required
  end

  private
  def run!
    id = SecureRandom.uuid
    USERS[id] = User.new(
      id,
      params[:name],
      params[:age]
    )
  end
end

class ShowUser < Bridger::Action
  schema do
    field(:user_id).type(:string).required
  end

  private
  def run!
    USERS.fetch(params[:user_id])
  end
end

class DeleteUser < Bridger::Action
  schema do
    field(:user_id).type(:string).required
  end

  private
  def run!
    USERS.delete(params[:user_id])
  end
end

class ListUsers < Bridger::Action
  schema do
    field(:q)
  end

  private
  def run!
    USERS.values.sort_by(&:name)
  end
end

# Serializers turn the result of actions into JSON structures
class RootSerializer < Bridger::Serializer
  schema do
    self_link
    rel :user
    rel :users
    rel :create_user

    link("btc:schemas", href: url("/schemas"))

    link("btc:docs",
     href: "https://developers.bootic.net",
     type: "text/html",
     title: "API documentation"
    )

    self_link
    property :welcome, "Welcome to this API"
  end
end

class UserSerializer < Bridger::Serializer
  schema do
    rel :user, as: 'self', user_id: item.id
    rel :delete_user, user_id: item.id
    rel :root

    property :id, item.id
    property :name, item.name
    property :age, item.age
  end
end

class UsersSerializer < Bridger::Serializer
  schema do
    rel :user
    rel :root

    items item, UserSerializer
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

# Your API's endpoints. Each combines an action, serializer, some metadata and a permissions scope.
Bridger::Endpoints.instance.build do
  endpoint(:root, :get, "/?",
    title: "API root",
    scope: "api.me",
    action: ShowRoot,
    serializer: RootSerializer,
  )

  endpoint(:users, :get, "/users",
    title: "List users",
    scope: "api.users.list",
    action: ListUsers,
    serializer: UsersSerializer,
  )

  endpoint(:user, :get, "/users/:user_id",
    title: "User details",
    scope: "api.users.list",
    action: ShowUser,
    serializer: UserSerializer,
  )

  endpoint(:create_user, :post, "/users",
    title: "Create a new user",
    scope: "api.users.create",
    action: CreateUser,
    serializer: UserSerializer,
  )

  endpoint(:delete_user, :delete, "/users/:user_id",
    title: "Delete user",
    scope: "api.users.delete",
    action: DeleteUser,
    serializer: nil,
  )
end

# Let's use Sinatra as the Rack vessel for our endpoints
# it will also exposes endpoint metadata publicly at /schemas
#
class TestAPI < Sinatra::Base
  register Sinatra::Bridger
  bridge Bridger::Endpoints.instance, schemas: true
end

