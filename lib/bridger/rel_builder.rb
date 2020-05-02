# frozen_string_literal: true

require 'bridger/rel'
module Bridger
  class RelBuilder
    DOMAIN_SEP = ':'.freeze

    def self.domain=(str)
      @domain = str
    end

    def self.domain
      @domain
    end

    attr_reader :name, :verb, :path, :title

    def initialize(name, verb, path, query_field_names = [], title = nil)
      @name, @verb, @path, = name, verb, path
      path_tokens = extract_path_tokens(path)
      @query_field_names = (query_field_names - path_tokens)
      @path = add_query(@path, @query_field_names) if @verb == :get && @query_field_names.any?
      @title = title
      templatize
    end

    def build(params = {})
      Rel.new(
        name: [self.class.domain, name].compact.join(DOMAIN_SEP),
        verb: verb,
        path: path,
        title: title,
        params: params
      )
    end

    private
    attr_reader :path, :query_field_names

    EXP = /:\w+/.freeze
    PATH_TOKEN_EXP = /:(\w+)/.freeze

    def templatize
      @path = @path.gsub(EXP) do |m|
        m = m.sub(/^:/, '')
        "{#{m}}"
      end
    end

    def add_query(path, query_field_names)
      p, q = path.split('?')
      if q
        q += "{&#{query_field_names.join(",")}}"
      else
        q = "{?#{query_field_names.join(",")}}"
      end

      [p, q].join
    end

    def extract_path_tokens(path)
      path.to_s.scan(PATH_TOKEN_EXP).map(&:first).map(&:to_sym)
    end
  end
end
