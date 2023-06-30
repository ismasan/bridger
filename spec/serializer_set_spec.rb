# frozen_string_literal: true

require 'spec_helper'
require 'bridger/serializer_set'
require 'bridger/result'

RSpec.describe Bridger::SerializerSet do
  subject(:set) { Bridger::SerializerSet::DEFAULT }

  describe 'defaults' do
    (200..203).each do |status|
      specify "#{status} is a success" do
        result = Bridger::Result::Success.build.continue do |r|
          r.response.status = status
        end

        result = set.run(result, service: nil, rel_name: nil)
        data = JSON.parse(result.response.body.first, symbolize_names: true)

        expect(result.response.headers['Content-Type']).to eq('application/json')
        expect(data[:_class]).to eq(['success'])
        expect(data[:message]).to eq('Hello World!')
      end
    end

    specify '204 is No Content' do
      result = Bridger::Result::Success.build.continue do |r|
        r.response.status = 204
      end

      result = set.run(result, service: nil, rel_name: nil)
      data = JSON.parse(result.response.body.first, symbolize_names: true)

      expect(result.response.headers['Content-Type']).to eq('application/json')
      expect(data).to eq({})
    end

    specify '422 is Unprocessable Content (invalid)' do
      result = Bridger::Result::Success.build.halt(errors: { '$.title' => ['is required']}).copy do |r|
        r.response.status = 422
      end

      result = set.run(result, service: nil, rel_name: nil)
      data = JSON.parse(result.response.body.first, symbolize_names: true)

      expect(result.response.headers['Content-Type']).to eq('application/json')
      expect(data[:_class]).to eq(['errors', 'invalid'])
      data.dig(:_embedded, :errors)[0].tap do |err|
        expect(err[:field]).to eq('$.title')
        expect(err[:messages]).to eq(['is required'])
      end
    end

    specify '401 is Unauthorized' do
      result = Bridger::Result::Success.build.halt do |r|
        r.response.status = 401
      end

      result = set.run(result, service: nil, rel_name: nil)
      data = JSON.parse(result.response.body.first, symbolize_names: true)

      expect(data[:_class]).to eq(['errors', 'unauthorized'])
      data.dig(:_embedded, :errors)[0].tap do |err|
        expect(err[:field]).to eq('access_token')
      end
    end

    specify '403 is Forbidden' do
      result = Bridger::Result::Success.build.halt do |r|
        r.response.status = 403
      end

      result = set.run(result, service: nil, rel_name: nil)
      data = JSON.parse(result.response.body.first, symbolize_names: true)

      expect(data[:_class]).to eq(['errors', 'forbidden'])
      data.dig(:_embedded, :errors)[0].tap do |err|
        expect(err[:field]).to eq('access_token')
      end
    end

    specify '404 is Not Found' do
      result = Bridger::Result::Success.build.halt do |r|
        r.response.status = 404
      end

      result = set.run(result, service: nil, rel_name: nil)
      data = JSON.parse(result.response.body.first, symbolize_names: true)

      expect(data[:_class]).to eq(['errors', 'notFound'])
      data.dig(:_embedded, :errors)[0].tap do |err|
        expect(err[:field]).to eq('$')
      end
    end

    specify '500 is Server Error' do
      result = Bridger::Result::Success.build.halt(data: { exception: ArgumentError.new('nope') }).copy do |r|
        r.response.status = 500
      end

      result = set.run(result, service: nil, rel_name: nil)
      data = JSON.parse(result.response.body.first, symbolize_names: true)

      expect(data[:_class]).to eq(['errors', 'serverError', 'ArgumentError'])
      expect(data[:message]).to eq('nope')
      data.dig(:_embedded, :errors)[0].tap do |err|
        expect(err[:field]).to eq('$')
      end
    end
  end

  describe 'extending defaults with #build_for' do
    subject(:set) do
      Bridger::SerializerSet::DEFAULT.build_for do |s|
        s.on(201, created_serializer)
        s.on(204, created_serializer)
      end
    end
    let(:created_serializer) do
      ->(result, auth:, h:) { { message: 'Ok' } }
    end

    [201, 204].each do |status|
      it "uses custom serializer for configured status #{status}" do
        result = Bridger::Result::Success.build.halt do |r|
          r.response.status = status
        end

        result = set.run(result, service: nil, rel_name: nil)
        data = JSON.parse(result.response.body.first, symbolize_names: true)
        expect(data[:message]).to eq('Ok')
      end
    end

    [200, 203, 205].each do |status|
      it "still fall backs to defaults for other statuses (#{status})" do
        result = Bridger::Result::Success.build.continue do |r|
          r.response.status = status
        end

        result = set.run(result, service: nil, rel_name: nil)
        data = JSON.parse(result.response.body.first, symbolize_names: true)

        expect(result.response.headers['Content-Type']).to eq('application/json')
        expect(data[:_class]).to eq(['success'])
      end
    end
  end
end