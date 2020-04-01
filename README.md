# Bridger

Utilities to build Hypermedia APIs in Ruby in any Rack framework (Sinatra helpers built-in).

## TL;DR

Define API endpoints like so:

```ruby
endpoint(:create_user, :post, '/users',
  title: "Create new user",
  scope: 'all.users.create',
  action: CreateUser,
  serializer: UserSerializer
)
```

These endpoints encapsulate rich information about each thing your API can do, regardless of the Rack/routing framework you use.
This information can be used to generate input schemas, documentation, and hypermedia links between different endpoints. The latter allows you to model not just individual HTTP requests, but workflows through your API. Some context [here](https://robots.thoughtbot.com/writing-a-hypermedia-api-client-in-ruby).

Bridger _does not_ tell you where to put your files, how to name your clases or what database library to use (if at all). The model and persistence layer are up to you.

On the testing side, it allows you to write high-level, feature-style tests for your REST API, such as:

```ruby
it "creates a user" do
  user = root.create_user(name: "Joe Bloggs")
  expect(user.name).to eq "Joe Bloggs"
end
```

The example above is testing a regular REST request that maps to a `create_user` name.

## Concepts

### Auth

An auth object has basic information and credentials for a request, normally taken from an access token

```ruby
config = Bridger::Auth::Config.new
config.token_store = {
  'mytoken' => {
    'uid' => 111
  }
}

auth = Bridger::Auth.parse(request, config) # HTTP_AUTHORIZATION = "Bearer mytoken"
auth.claims['uid'] # 111
```

`Bridger::Auth` can be configured to extract token from request headers or query string, and to use JWT tokens, a custom token store, a Hash, etc.

See more about token stores below.

### Action

An action defines payload parameters, runs them through a method and returns a data object. It uses [Parametric](https://github.com/ismasan/parametric).

```ruby
class CreateUser < Bridger::Action
  payload_schema do
    field(:name).type(:string).required
  end

  def run
    # schema validations run before this
    SomeDatabaseObject.create!(payload)
  end
end

user = CreateUser.call(payload: {name: "Joe"}, auth: auth)
# will raise validation errors if parameters don't comply with schema
```

Optionally, actions can also define a _query schema_, ie. parameters passed separately and used to locate existing records.

```ruby
class UpdateUser < Bridger::Action
  query_schema do
    field(:user_id).type(:integer).present
  end

  payload_schema do
    field(:name).type(:string).required
  end

  def run
    # use query params to locate existing user
    user = SomeDatabaseObject.find(query[:user_id])

    # now update user with payload parameters
    user.update!(payload)
  end
end

user = CreateUser.call(payload: {name: "Joe"}, auth: auth)
user = UpdateUser.call(query: {user_id: user.id}, payload: {name: "Joan"}, auth: auth)
```

### Serializer

A serializer describes how a data object is converted into a JSON Hash. It uses [Oat](https://github.com/ismasan/oat).

Serializers have helpers to add links between resources, based upon registered endpoints (see below).

```ruby
class UserSerializer < Bridger::Serializer
  schema do
    # link to self (current URL)
    rel :user, id: item.id, as: :self
    # link to another endpoint
    # will only be included if current credentials have permissions to other endpoint
    rel :update_user, user_id: item.id
    property :id, item.id
    property :name, item.name
  end
end

# serialize user data.
# request helper includes request info so serialized data can include fully-qualified links.
user_data = UserSerializer.new(user, h: request_helper, auth: auth).to_hash
```

### Service endpoints

A service is a collection of _endpoints_. An endpoint combines auth, action and serializer into a callable object that fulfills an entire API request (albeit being framework agnostic).
Endpoints include access scopes and pass information to serializers so they can generate (or not) links to other endpoints, based on permissions.

```ruby
Bridger::Service.instance.build do
  endpoint(:root, :get, '/?',
    title: "API root",
    scope: 'all.me',
    action: ShowRoot,
    serializer: RootSerializer
  )
  endpoint(:user, :get, '/users/:user_id',
    title: "User details",
    scope: 'all.users',
    action: ShowUser,
    serializer: UserSerializer
  )
  endpoint(:create_user, :post, '/users',
    title: "Create new user",
    scope: 'all.users.create',
    action: CreateUser,
    serializer: UserSerializer
  )

  # This will register built-in endpoints for /schemas and /schemas/:rel
  # that, when mounted in a Rack app, will generate JSON endpoints
  # describing all other endpoints in this service
  schema_endpoints(path: '/schemas', scope: 'all.schemas')
end
```

Endpoints can be invoked on their own.

```ruby
endpoint = Bridger::Service.instance[:create_user]
user_data = endpoint.run!(
  # payload is user-provided data to be passed to action
  payload: {name: "Joe"},
  # auth data is extracted from request
  auth: Bridger::Auth.parse(request),
  # helper is whatever subset of request info you want available in serializers
  helper: request_helper
)
```

But it's more useful to integrate them with your Rack framework of choice.

Serializers can then include links to other endpoints.

```ruby
# some_serializer.rb
schema do
  rel :create_user
end
```

With the default adapter, the example above results in the following JSON entity

```json
{
  "_links": {
    "create_user": {
      "href": "https://myapi.com/users",
      "method": "post",
      "title": "Create a new user",
      "templated": false
    }
  }
}
```

The `rel` helper will only add links if your current scope has permissions over the target endpoint.

## Sinatra integration

This gem includes Sinatra integration:

```ruby
require 'sinatra/bridger'
require 'sinatra/base'

class API < Sinatra::Base
  extend Sinatra::Bridger
  bridge Bridger::Service.instance, logger: Logger.new(STDOUT)
end
```

Now your Sinatra app exposes all registered endpoints, runs scope-based permissions, validates input parameters and includes links between resources.

See a full example in the bundled [test API](https://github.com/ismasan/bridger/blob/master/spec/support/test_service.rb), and check out how [it's tested](https://github.com/ismasan/bridger/blob/master/spec/support/api_examples.rb).

## Rails integration

In your Rails router

```ruby
require 'bridger/rails'

Rails.application.routes.draw do
  mount Bridger::Rails.router_for(Bridger::Service.instance) => '/api'
  # etc
end
```

You can also mount multiple `Bridger::Service` instances separately.

```ruby
Rails.application.routes.draw do
  mount Bridger::Rails.router_for(service_1) => '/api'
  mount Bridger::Rails.router_for(service_2) => '/admin-api'
  # ... etc
end
```

## Scopes and authorization

Scopes are permission trees.
For example, the scope `all.users.create` represents the following structure:

```
all
  users
    create
```

A request's token scope is compared with a given endpoint's token to check access permissions, from left to right.

* `all` has access to `all`
* `all` has access to `all.users`
* `all.users` has access to `all.users.create`
* `all.accounts` does NOT have access to `all.users`
* `all.accounts` does NOT have access to `all.users.create`

_Wildcard_ scopes are possible using the special character `*` as one or more segments in a scope.
For example:

* `all.*.create` has access to `all.accounts.create` or `all.photos.create`
* `all.*.create` has access to `all.accounts.*`
* `all.*.create.*` does not have access to `all.accounts.create` (because it's more specific).

Sometimes you'll want to authorize based on ownership. For example, I can only update a user whose ID is included in my credentials.
For that you can define guard blocks that run at a specific branch of an endpoint's scope:

```ruby
Bridger::Service.instance do
  # run this block when hitting an endpoint with `all.users.update` scope
  # and verify that targeted user is present in my access token info
  authorize "all.users.update" do |scope, auth, params|
    auth.claims['user_id'].to_i == params[:user_id].to_i
  end

  endpoint(:update_user, :put, '/users/:user_id',
    title: "Update a user",
    scope: 'all.user.update',
    action: UpdateUser,
    serializer: UserSerializer
  )
end
```

## Testing

Bridger attempts to make testing hypermedia APIs easier.
It includes a [hypermedia-aware API client](https://github.com/bootic/bootic_client.rb) so you can follow links in your tests as you would as a consumer of the API.

```ruby
# spec/api_spec.rb

require 'spec_helper'
require 'bridger/test_helpers'
require_relative '../api'

RSpec.describe App do
  include Bridger::TestHelpers

  # make sure to define this method to point to your Rack app
  def app
    API
  end

  before :all do
    # configure Bridger::Auth to take access token from Authorization header
    # using an in-memory hash for token storage
    # in production you can configure a JWT token store with a public RSA key to verify token validity
    Bridger::Auth.config do |c|
      c.parse_from :header, 'HTTP_AUTHORIZATION'
      c.token_store = {}
      # alternative JWT token store
      # c.token_store = Bridger::JWTTokenStore.new(ENV.fetch("RSA_PUBLIC_KEY"))
      c.logger = Logger.new(STDOUT)
    end
  end

  it "creates user" do
    # this creates a valid test token with these claims and scopes
    authorize!(
      uid: 123,
      scopes: ["all"]
    )
    # root entity (request to API root) is provided
    # any links will be exposed as methods in API client entities
    user = root.create_user(name: "Joe")
    expect(user.name).to eq "Joe"
    expect(user.id).not_to be_nil

    # follow "self" link
    user = user.self
    expect(user.name).to eq "Joe"
  end
end
```

... So you can test an API by _using it_. High level feature-tests for your API!

Hypermedia links will be not be present if your current scope doesn't have permissions over the target endpoint:

```ruby
it "does not let incorrect scope create user" do
  authorize!(
    uid: 123,
    scopes: ["all.me"] # create_user requires 'all.users.create' scope
  )
  expect(root.can?(:create_user)).to be false
end
```

Making a direct call to an unauthorized endpoint will respond with a `403 Forbidden` JSON error response.

## Auth token stores

At the simplest, you can use an in-memory hash to store valid access tokens and their claims. This is useful in tests and quick prototypes.

```ruby
Bridger::Auth.config do |c|
  c.token_store = {}
end
```

You can also provide a custom token store.

```ruby
class DatabaseAccessToken < ActiveRecord::Base
  validates :access_token, presence: true
  serialize :claims

  def self.set(claims)
    token = create!(
      access_token: SecureRandom.hex,
      claims: claims
    )
    token.access_token
  end

  def self.get(access_token)
    token = find_by(access_token: access_token)
    token.present? ? token.claims : nil
  end
end

Bridger::Auth.config do |c|
  c.token_store = DatabaseAccessToken
end
```

### JWT (JSON Web Tokens)

JWT tokens are JSON objects that contain all permission information right there in the token, encoded and signed cryptographically so they can't be tampered with.
The JWT token store uses the [Ruby JWT library](https://github.com/jwt/ruby-jwt) to decode and verify tokens.

```ruby
require 'bridger/jwt_token_store'
Bridger::Auth.config do |c|
  c.token_store = Bridger::JWTTokenStore.new("mys3cr3t", algo: 'HS256')
end
```

The example above uses a string secret to verify token signatures created with the same secret.

You can use one of the supported RSA (asymmetric) algorithms, where the tokens are signed with a private key by a third party (ie. an identity service). Your app then only needs a matching _public_ key to verify them.

```ruby
require 'bridger/jwt_token_store'
Bridger::Auth.config do |c|
  # public key can be a string, a Pathname or IO instance, or an OpenSSL::PKey::RSA instance.
  c.token_store = Bridger::JWTTokenStore.new(File.new("/path/to/public_key.rsa"), algo: 'RS512')
end
```

### Generating tokens

Note that all token stores can be used to generate tokens, too (useful in development, tests, or to build your own identity service).

```ruby
store = c.token_store = Bridger::JWTTokenStore.new("mys3cr3t", algo: 'HS256')
token = store.set(
  user_id: 1,
  scopes: ["admin"]
)

claims = store.get(token)
```

RSA tokens are signed with a separate private key, which you'll have to pass on initialization.

```ruby
store = c.token_store = Bridger::JWTTokenStore.new(
  File.new("/path/to/public_key.rsa"),
  pkey: File.new("/path/to/private_key.rsa"),
  algo: 'RS512'
)
token = store.set(
  user_id: 1,
  scopes: ["admin"]
)
```

## Instrumentation

Bridger services accept an optional _instrumenter_ interface, compatible with [ActiveSupport::Notifications](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html).

```ruby
Bridger::Service.instance.build do
  # Register a service-level instrumenter for all endpoints
  instrumenter ActiveSupport::Notifications

  endpoint(:user, :get, '/users/:id',
    title: "List users",
    scope: 'all.me',
    action: ListUsers,
    serializer: UsersSerializer
  )
end
```

This instruments two components of every endpoint run. As per the example `:user` endpoint above:

```ruby
# Instrument action call
instrumenter.instrument('bridger.action', {
  class_name: 'ListUsers',
  verb: :get,
  path: '/users/:id',
  name: :user,
  title: 'List users'
})

# Instrument serializer call
instrumenter.instrument('bridger.serializer', { class_name: 'UsersSerializer' })
```

### Custom instrumenters

You can provide your own instrumenter, for example:

```ruby
class PutsInstrumenter
  def instrument(name, payload = {}, &block)
    start = Time.now
    results = block.call
    puts "#{name} #{payload[:class_name]} took #{Time.now - now} seconds"
    # don't forget to return the result back to the caller
    results
  end
end

# Register it in your services
Bridger::Service.instance.build do
  instrumenter PutsInstrumenter.new

  # .. etc
end
```

## To DO

* API console (`bridger console`) so you can interact with your API in an IRB session.
* New version of Oat with schema reflection, so we can auto-document output schemas too
* Helpers to build API-powered frontends.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bridger'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install bridger

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ismasan/bridger.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
