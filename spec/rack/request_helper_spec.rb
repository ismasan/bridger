# frozen_string_literal: true

require 'spec_helper'
require 'bridger/request_helper'

RSpec.describe Bridger::RequestHelper do
  let(:service) { instance_double(Bridger::Service) }

  it 'exposes a limited set of public methods required by serializers' do
    req = Rack::Request.new(Rack::MockRequest.env_for(
      "http://example.com/a/b?foo=bar&one=1"
    ))
    helper = described_class.new(service, req, params: { foo: 'bar', one: '1' }, rel_name: :users)
    expect(helper.service).to eq service
    expect(helper.rel_name).to eq :users
    expect(helper.url).to eq 'http://example.com/a/b'
    expect(helper.current_url).to eq 'http://example.com/a/b'
    expect(helper.url('foo/bar')).to eq 'http://example.com/foo/bar'
    expect(helper.params).to eq({foo: 'bar', one: '1'})
  end

  describe '#url' do
    it 'works with forwarded hosts' do
      req = Rack::Request.new(Rack::MockRequest.env_for(
        'http://example.com/a/b?foo=bar&one=1',
        {'HTTP_X_FORWARDED_HOST' => 'foo.bar.com:123'}
      ))
      helper = described_class.new(service, req, rel_name: :users)
      expect(helper.url('/yes')).to eq 'http://foo.bar.com:123/yes'
    end
  end
end
