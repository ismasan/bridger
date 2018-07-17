require "parametric/dsl"

module Bridger
  class ValidationErrors < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super
    end
  end

  class Action
    include Parametric::DSL

    def self.run!(*args)
      new(*args).call
    end

    def initialize(payload: {}, auth: nil)
      @payload = payload
      @auth = auth
    end

    def params
      @params ||= map(validator.output)
    end

    def call
      if !validator.valid?
        raise ValidationErrors.new(validator.errors)
      end

      run!
    end

    private
    attr_reader :payload, :auth

    def run!

    end

    def validator
      @validator ||= schema.resolve(payload)
    end

    def schema
      self.class.schema
    end

    def map(hash)
      hash
    end
  end
end
