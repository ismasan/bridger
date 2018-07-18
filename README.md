# Bridger

Utilities to build Hypermedia APIs in Ruby in any Rack framework (Sinatra helpers built-in).

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

### Action

An action defines payload parameters, runs them through a method and returns a data object. It uses [Parametric](https://github.com/ismasan/parametric).

```ruby
class CreateUser < Bridger::Action
  schema do
    field(:name).type(:string).required
  end

  def run!
    # schema validations run before this
    SomeDatabaseObject.create!(params)
  end
end

user = CreateUser.run!(payload: {name: "Joe"}, auth: auth)
# will raise validation errors if parameters don't comply with schema
```

### Serializer

A serializer describes how a data object is converted into a JSON Hash. It uses [Oat](https://github.com/ismasan/oat)
Serializers have helpers to add links between resources, based upon registered endpoints (see below).

```ruby
class UserSerializer < Bridger::Serializer
  schema do
    # link to another endpoint
    rel :update_user, user_id: item.id
    property :id, item.id
    property :name, item.name
  end
end
```

### Endpoints

An endpoint combines auth, action and serializer into a callable object that fulfills an entire API request (albeit being framework agnostic).
Endpoints incluse access scopes and give serializers information to include (or not) links to other endpoints, based on permissions.

```ruby
Bridger::Endpoints.instance do
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
end
```

Endpoints can be invoked on their own.

```ruby
endpoint = Bridger::Endpoints.instance[:create_user]
user_data = endpoint.run!(
  # payload is user-provided data to be passed to action
  payload: {name: "Joe"},
  # auth data is extracted from request
  auth: Bridger::Auth.parse(request),
  # helper is whatever subset of request info you want available in serializers
  helper: some_helper_object
)
```

## Sinatra integration

This gem includes Sinatra integration:

```ruby
require 'bridger'
require 'sinatra/base'

class API < Sinatra::Base
  register Sinatra::Bridger
  bridge  Bridger::Endpoints.instance
end
```

Now your Sinatra app esposes all registered endpoints, runs scope-based permissions, validates input parameters and includes links between resources.

## Schemas

`Bridger::Action` classes contain detailed information on your input schemas and validations.
These can be exposed as JSON endpoints under `/schemas` in your API, with

```ruby
class API < Sinatra::Base
  register Sinatra::Bridger
  bridge  Bridger::Endpoints.instance, schemas: true
end
```

You can then use schema information to build client-side validation, auto-generated documentation, etc.

## Testing

Bridger attempts to make testing hypermedia APIs easier. It includes a [hypermedia-aware API client](https://github.com/bootic/bootic_client.rb) so you can follow links in your test as you would as a consumer of the API.

```ruby
# spec/api_spec.rb

require 'spec_helper'
require 'bridger/test_helpers'
require_relative '../API'

RSpec.describe App do
  include Bridger::TestHelpers

  # make sure to define this method to point to your Rack app
  def app
    API
  end

  before :all do
    # configure Bridger::Auth to take access token from Authorization header
    # using JWT token strategy, signed with provided test RSA secret
    # in production you can configure these with different secrets
    # a private key is needed to sign tokens, but only a public one
    # is needed to verify 3rd party tokens (ex. a separate identity service)
    Bridger::Auth.config do |c|
      c.parse_from :header, 'HTTP_AUTHORIZATION'
      c.public_key = test_private_key.public_key
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

You can check permission errors:

```ruby
it "does not let incorrect scope create user" do
  authorize!(
    uid: 123,
    scopes: ["all.me"] # create_user requires 'all.users.create' scope
  )
  # HTTP errors are raised by BooticClient gem
  expect{
    user = root.create_user(name: "Joe")
  }.to raise_error BooticClient::AccessForbiddenError
end
```

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

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/bridger.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
