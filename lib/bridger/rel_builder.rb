require 'bridger/rel'
module Bridger
  class RelBuilder
    REL_DOMAIN = "btc".freeze

    attr_reader :name, :verb, :path, :title

    def initialize(name, verb, path, query_field_names = [], title = nil)
      @name, @verb, @path, @query_field_names = name, verb, path, query_field_names
      @path = add_query(@path, @query_field_names) if @verb == :get && @query_field_names.any?
      @title = title
      templatize
    end

    def build(params = {})
      Rel.new(
        name: [REL_DOMAIN, name].join(':'),
        verb: verb,
        path: path,
        title: title,
        params: params
      )
    end

    private
    attr_reader :path, :query_field_names

    EXP = /:\w+/.freeze

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
  end

end
