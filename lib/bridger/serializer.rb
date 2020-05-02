# frozen_string_literal: true

require 'oat'
require 'oat/serializer'
require 'oat/adapters/hal'

module Bridger
  class DefaultAdapter < Oat::Adapters::HAL
    def type(*types)
      property :_class, *types
    end

    def items(collection, serializer_class = nil, &block)
      entities :items, collection, serializer_class, &block
    end
  end

  class Serializer < Oat::Serializer
    adapter DefaultAdapter

    def self.call(item, context = {})
      new(item, context).to_hash
    end

    def inspect
      %(<#{self.class.name}>)
    end

    def rel(name, opts = {})
      as = opts.delete(:as)
      always = opts.delete(:always)

      endpoint = h.service[name]
      raise "no endpoint defined for name ':#{name}'" unless endpoint

      return unless always || endpoint.authorized?(auth, opts)

      r = endpoint.build_rel(opts)

      args = {
        href: url(r.path),
        templated: r.templated?,
        method: r.verb
      }

      args[:title] = r.title if r.title

      name = as || r.name

      link name, args
    end

    def rel_directory
      h.service.each do |endpoint|
        rel endpoint.name
      end
    end

    def self_link
      link :self, href: h.current_url
    end

    def current_rel(params = {})
      rel h.rel_name, h.params.merge(params)
    end

    def url(path)
      h.url path
    end

    def h
      context[:h]
    end

    def auth
      context[:auth]
    end
  end
end
