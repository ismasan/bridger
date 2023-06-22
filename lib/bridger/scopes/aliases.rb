# frozen_string_literal: true

module Bridger
  class Scopes
    # Aliases for scopes
    # Example:
    #  aliases = Aliases.new('read' => ['read.users'])
    #  aliases.map('read') # => ['read.users']
    #  aliases.map('read:users') # => ['read.users']
    class Aliases
      # @param [Hash<String, Array<String>>] scope mapping
      def initialize(mapping = {})
        @mapping = mapping
      end

      # Map scopes to aliases
      # Example:
      # aliases = Aliases.new('read' => ['read.users'])
      # aliases.map('read') # => ['read.users']
      #
      # @param [Array<String>] scopes
      # @return [Scopes]
      def map(scopes)
        scpes = Array(scopes.to_a).reduce([]){|memo, sc|
          memo + Array(@mapping.fetch(sc, sc))
        }.uniq

        Scopes.wrap(scpes)
      end

      # Expand scopes with aliases, including original scopes
      # Example:
      #
      # aliases = Aliases.new('read' => 'read.users')
      # aliases.expand('read') # => Scopes['read', 'read.users']
      #
      # @param [Array<String>] scopes
      # @return [Scopes]
      def expand(scopes)
        scopes = Array(scopes.to_a)
        registered_scopes = scopes.filter { |sc| @mapping.key?(sc) }
        result = registered_scopes + registered_scopes.reduce([]) { |memo, sc|
          memo + Array(@mapping.fetch(sc))
        }.uniq

        Scopes.wrap(result)
      end
    end
  end
end
