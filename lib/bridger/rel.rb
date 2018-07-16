module Bridger
  class Rel
    TEMPLATED_QUERY_EXP = /{(\?|\&)([^}]+)}/.freeze
    EXISTING_QUERY_EXP = /\?(\w+=[^{.+]&?)+/.freeze

    attr_reader :name, :verb, :path, :title, :params

    def initialize(name:, verb:, path:, title: nil, params: {})
      @name, @verb, @path, @title, @params = name, verb, path, title, string_keys(params)
      build
    end

    def templated?
      !!(path =~ /{/)
    end

    private

    def build
      clean_path = params.reduce(@path) do |str, (k, v)|
        str.gsub("{#{k}}", v.to_s)
      end

      templated_query_match = clean_path.match(TEMPLATED_QUERY_EXP)
      clean_path.gsub!(TEMPLATED_QUERY_EXP, '') if templated_query_match

      existing_query_match = clean_path.match(EXISTING_QUERY_EXP)

      query = {}

      if existing_query_match
        clean_path.gsub!(EXISTING_QUERY_EXP, '')
        query = parse_query(existing_query_match[0])
      end

      templated_query_params = templated_query_match ? (templated_query_match[2] || "").split(",") : []
      # templated params with provided values
      provided_query_params = templated_query_params.find_all{|f| params.key?(f) }
      # remaining params
      remaining_query_params = templated_query_params - provided_query_params
      # populate available query params
      provided_query_params.each do |k|
        query[k] = params[k]
      end

      @path = clean_path
      @path += "?#{to_query(query)}" if query.any?
      init = query.any? ? "&" : "?"
      @path += "{#{init}#{remaining_query_params.join(",")}}" if remaining_query_params.any?
    end

    def parse_query(q)
      q.to_s.sub("?", "").split("&").each_with_object({}) do |pair, memo|
        k, v = pair.split("=")
        memo[k] = v
      end
    end

    def string_keys(hash)
      hash.each_with_object({}){|(k, v), m| m[k.to_s] = v}
    end

    def to_query(hash)
      hash.each_with_object([]){ |(k, v), memo|
        memo << [k, v].join("=")
      }.join("&")
    end
  end
end
