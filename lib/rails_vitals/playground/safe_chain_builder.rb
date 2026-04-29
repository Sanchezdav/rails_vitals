require "strscan"

module RailsVitals
  module Playground
    class SafeChainBuilder
      ALLOWED_METHODS = %w[
        all where select limit offset order group
        includes preload eager_load joins left_joins
        find find_by first last count sum average
        pluck distinct having references unscoped not
      ].freeze

      DISALLOWED_CLASS_METHODS = %w[
        connection execute exec system eval send public_send __send__
        instance_eval class_eval module_eval define_method method_missing
        delete destroy delete_all destroy_all update_all
      ].freeze

      ParseError = Class.new(StandardError)

      def self.build(chain_str, model)
        relation = model.all
        parse_chain(chain_str).each do |method_name, args|
          if DISALLOWED_CLASS_METHODS.include?(method_name)
            raise ParseError, "Method '#{method_name}' is not allowed for security reasons"
          end
          unless ALLOWED_METHODS.include?(method_name)
            raise ParseError, "Method '#{method_name}' is not allowed. Allowed: #{ALLOWED_METHODS.join(', ')}"
          end
          relation = relation.public_send(method_name, *args)
        end

        raise ParseError, "Expression must return an ActiveRecord::Relation" unless relation.is_a?(ActiveRecord::Relation)
        relation
      end

      private

      def self.parse_chain(str)
        scanner = StringScanner.new(str)
        calls = []
        scanner.skip(/\s+/)

        until scanner.eos?
          scanner.skip(/\.\s*/)

          name = scanner.scan(/[a-z_][a-zA-Z0-9_!?]*/)
          raise ParseError, "Expected method name at position #{scanner.pos}" unless name

          scanner.skip(/\s+/)
          if scanner.scan(/\(/)
            args = parse_args(scanner)
            scanner.skip(/\s*\)/)
            calls << [ name, args ]
          else
            calls << [ name, [] ]
          end
          scanner.skip(/\s+/)
        end

        calls
      end

      def self.parse_args(scanner)
        args = []
        scanner.skip(/\s+/)
        return args if scanner.eos? || scanner.peek(1) == ")"

        loop do
          scanner.skip(/\s+/)
          break if scanner.eos? || scanner.peek(1) == ")"

          if keyword_hash_start?(scanner)
            args << scan_keyword_hash(scanner)
          else
            args << scan_value(scanner)
          end

          scanner.skip(/\s+/)
          break unless scanner.scan(/,/)
        end

        args
      end

      def self.keyword_hash_start?(scanner)
        pos = scanner.pos
        ident = scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
        return false unless ident

        scanner.skip(/\s*/)

        if scanner.scan(/:/) && !scanner.scan(/:/)
          scanner.pos = pos
          return true
        end

        scanner.pos = pos
        false
      end

      def self.scan_keyword_hash(scanner)
        hash = {}
        loop do
          scanner.skip(/\s+/)
          break if scanner.eos? || scanner.peek(1) == ")" || scanner.peek(1) == "}"

          key = scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
          raise ParseError, "Expected hash key" unless key
          scanner.skip(/\s*:\s*/)
          value = scan_value(scanner)
          hash[key.to_sym] = value
          scanner.skip(/\s+/)
          break unless scanner.scan(/,/)
        end
        hash
      end

      def self.scan_value(scanner)
        scanner.skip(/\s+/)
        ch = scanner.peek(1)
        raise ParseError, "Unexpected end of expression" unless ch

        case ch
        when "'" then scan_single_quoted_string(scanner)
        when '"' then scan_double_quoted_string(scanner)
        when ":" then scan_symbol(scanner)
        when "t"
          if scanner.scan(/true\b/)
            true
          else
            raise ParseError, "Unexpected token at position #{scanner.pos}"
          end
        when "f"
          if scanner.scan(/false\b/)
            false
          else
            raise ParseError, "Unexpected token at position #{scanner.pos}"
          end
        when "n"
          if scanner.scan(/nil\b/)
            nil
          else
            raise ParseError, "Unexpected token at position #{scanner.pos}"
          end
        when "[" then scan_array(scanner)
        when "{" then scan_hash_literal(scanner)
        when "-", "+", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" then scan_number(scanner)
        else
          raise ParseError, "Unexpected token '#{ch}' at position #{scanner.pos}"
        end
      end

      def self.scan_single_quoted_string(scanner)
        scanner.pos += 1
        result = +""
        until scanner.eos?
          case scanner.peek(1)
          when "'"
            scanner.pos += 1
            return result
          when "\\"
            scanner.pos += 1
            escaped = scanner.getch
            case escaped
            when "'" then result << "'"
            when "\\" then result << "\\"
            else result << "\\#{escaped}"
            end
          else
            result << scanner.getch
          end
        end
        raise ParseError, "Unterminated single-quoted string"
      end

      def self.scan_double_quoted_string(scanner)
        scanner.pos += 1
        result = +""
        until scanner.eos?
          case scanner.peek(1)
          when '"'
            scanner.pos += 1
            return result
          when "\\"
            scanner.pos += 1
            escaped = scanner.getch
            case escaped
            when '"' then result << '"'
            when "\\" then result << "\\"
            when "n" then result << "\n"
            when "t" then result << "\t"
            when "r" then result << "\r"
            when "#" then result << "#"
            else result << "\\#{escaped}"
            end
          else
            result << scanner.getch
          end
        end
        raise ParseError, "Unterminated double-quoted string"
      end

      def self.scan_symbol(scanner)
        scanner.pos += 1
        if scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
          scanner.matched.to_sym
        elsif (str = scanner.scan(/"[^"]*"/) || scanner.scan(/'[^']*'/))
          str[1..-2].to_sym
        else
          raise ParseError, "Invalid symbol at position #{scanner.pos}"
        end
      end

      def self.scan_number(scanner)
        num_str = scanner.scan(/-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?/)
        raise ParseError, "Invalid number at position #{scanner.pos}" unless num_str
        if num_str.include?(".") || num_str.match?(/[eE]/)
          num_str.to_f
        else
          num_str.to_i
        end
      end

      def self.scan_array(scanner)
        scanner.pos += 1
        arr = []
        scanner.skip(/\s+/)
        unless scanner.peek(1) == "]"
          loop do
            arr << scan_value(scanner)
            scanner.skip(/\s+/)
            break unless scanner.scan(/,/)
            scanner.skip(/\s+/)
          end
        end
        scanner.skip(/\s*\]/)
        raise ParseError, "Unterminated array" unless scanner.matched
        arr
      end

      def self.scan_hash_literal(scanner)
        scanner.pos += 1
        hash = {}
        scanner.skip(/\s+/)
        unless scanner.eos? || scanner.peek(1) == "}"
          loop do
            scanner.skip(/\s+/)
            break if scanner.eos? || scanner.peek(1) == "}"

            key = parse_hash_key(scanner)
            scanner.skip(/\s+/)

            if scanner.scan(/=>/)
              scanner.skip(/\s+/)
              hash[key] = scan_value(scanner)
            elsif scanner.scan(/:\s*/)
              hash[key.to_sym] = scan_value(scanner)
            else
              raise ParseError, "Expected '=>' or ':' after hash key"
            end

            scanner.skip(/\s+/)
            break unless scanner.scan(/,/)
          end
        end
        scanner.skip(/\s*}/)
        raise ParseError, "Unterminated hash" unless scanner.matched
        hash
      end

      def self.parse_hash_key(scanner)
        case scanner.peek(1)
        when '"', "'" then scan_string(scanner)
        when ":" then scan_symbol(scanner)
        else
          ident = scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
          raise ParseError, "Expected hash key" unless ident
          ident
        end
      end

      def self.scan_string(scanner)
        case scanner.peek(1)
        when "'" then scan_single_quoted_string(scanner)
        when '"' then scan_double_quoted_string(scanner)
        else raise ParseError, "Expected string"
        end
      end
    end
  end
end
