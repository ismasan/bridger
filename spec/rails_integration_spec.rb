require 'spec_helper'
require_relative './support/test_service'
require_relative './support/api_examples'

require 'action_dispatch'
require 'bridger/rails'

# Let's use Sinatra as the Rack vessel for our endpoints
# it will also exposes endpoint metadata publicly at /schemas
#
RSpec.describe 'Rails integration' do
  def app
    @app ||= Bridger::Rails.router_for(Bridger::Service.instance)
  end

  it_behaves_like 'a REST API exposing a Bridger service'
end
