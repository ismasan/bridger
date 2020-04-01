require 'spec_helper'
require_relative './support/test_service'
require_relative './support/api_examples'

require 'sinatra/bridger'
require 'sinatra/base'
require 'logger'

# Let's use Sinatra as the Rack vessel for our endpoints.
# It will also expose endpoint metadata publicly at /schemas
#
RSpec.describe 'Sinatra integration' do
  def app
    @app ||= Class.new(Sinatra::Base) do
      extend Sinatra::Bridger
      bridge Bridger::Service.instance, logger: Logger.new(STDOUT)
    end
  end

  it_behaves_like 'a REST API exposing a Bridger service'
end
