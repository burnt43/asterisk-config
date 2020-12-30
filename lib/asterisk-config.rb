module AsteriskConfig
  module Category
    class Base
      attr_reader :full_name

      def initialize(full_name)
        @full_name = full_name
        @attrs = {}
      end

      # instance methods

      # State Altering Methods
      def add_attr(name, value)
        @attrs[ActiveSupport::Inflector.underscore(name).to_sym] = value
      end

      # Meta-Programming Methods

      INTEGER_RANGE_REGEX = /\A(\d+)\-(\d+)\z/
      def method_missing(method_name, *args, &block)
        if @attrs.key?(method_name)
          result = @attrs[method_name]

          if args[0] && args[0].key?(:as)
            case args[0][:as]
            when :range
              if (match_data = INTEGER_RANGE_REGEX.match(result))
                (match_data.captures[0].to_i..match_data.captures[1].to_i)
              else
                nil
              end
            when :int
              result.to_i
            when :array
              result.split(',')
            end
          else
            result
          end
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @attrs.key?(method_name) || super
      end
    end
  end

  class Parser
    COMMENT_REGEX = /\A;/
    CATEGORY_HEADER_REGEX = /\A\[([\w\-]+)\]\z/
    VALUE_REGEX = /\A([\w\-]+)\s?=>\s?(.*)\z/

    def initialize(
      file_path,
      host='localhost',
      parse_as: AsteriskConfig::Category::Base,
      ssh_kex_algorithm: nil
    )
      @file_path = file_path
      @host = host

      @parse_as = parse_as
      @ssh_options = {
        kex_algorithm: ssh_kex_algorithm
      }
    end

    # instance methods
    def parse
      result = {}
      state = :looking_for_category_header
      current_category = nil

      my_raw_config = raw_config

      return if my_raw_config.size.zero?

      my_raw_config.lines.each do |line|
        stripped_line = line.strip

        case state
        when :looking_for_category_header
          if stripped_line =~ COMMENT_REGEX
            # NOOP
          elsif (match_data = CATEGORY_HEADER_REGEX.match(stripped_line))
            category_name = match_data.captures[0]
            current_category = @parse_as.new(category_name)
            state = :looking_for_values
          end
        when :looking_for_values
          if stripped_line =~ COMMENT_REGEX
            # NOOP
          elsif (match_data = VALUE_REGEX.match(stripped_line))
            name = match_data.captures[0] 
            value = match_data.captures[1]
            current_category.add_attr(name, value)
          elsif (match_data = CATEGORY_HEADER_REGEX.match(stripped_line))
            result[current_category.full_name] = current_category

            category_name = match_data.captures[0]
            current_category = @parse_as.new(category_name)
            state = :looking_for_values
          end
        end
      end

      if current_category
        result[current_category.full_name] = current_category
      end

      result
    end

    private

    def ssh_bin
      @ssh_bin ||= %x[which ssh].strip
    end

    def ssh_option_string
      options = []

      if @ssh_options.key?(:kex_algorithm)
        options.push("-oKexAlgorithms=+#{@ssh_options[:kex_algorithm]}")
      end

      options.join(' ')
    end

    def raw_config
      if local?
        %x[cat #{@file_path}]
      else
        %x[#{ssh_bin} #{ssh_option_string} #{@host} "[[ -e #{@file_path} ]] && cat #{@file_path}"]
      end
    end

    def local?
      @host == 'localhost'
    end
  end
end
