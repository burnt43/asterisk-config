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
        attr_name = ActiveSupport::Inflector.underscore(name).to_sym

        if @attrs.key?(attr_name)
          if @attrs[attr_name].is_a?(Array)
            # An existing array value means just push the new value onto
            # the array.
            @attrs[attr_name].push(value)
          else
            # An existing, non-array value means we must convert the existing
            # value into an array and then push the new value onto it.
            existing_scalar_value = @attrs[attr_name]
            @attrs[attr_name] = [existing_scalar_value, value]
          end
        else
          # If no existing value, then just set the value.
          @attrs[attr_name] = value
        end
      end

      # Meta-Programming Methods

      INTEGER_RANGE_REGEX = /\A(\d+)(\-(\d+))?\z/
      def method_missing(method_name, *args, &block)
        if @attrs.key?(method_name)
          result = @attrs[method_name]

          if args[0] && args[0].key?(:as)
            case args[0][:as]
            when :range
              range_conversion = ->(input) {
                if (match_data = INTEGER_RANGE_REGEX.match(input))
                  start_range = match_data.captures[0].to_i
                  end_range = match_data.captures[2].to_i || start_range

                  (start_range..end_range)
                else
                  nil
                end
              }

              if result.is_a?(Array)
                result.map {|x| range_conversion.call(x)}
              else
                range_conversion.call(result)
              end
            when :int
              int_conversion = ->(input) {
                input.to_i
              }

              if result.is_a?(Array)
                result.map {|x| int_conversion.call(x)}
              else
                int_conversion.call(result)
              end
            when :array
              array_conversion = ->(input) {
                input.split(',')
              }

              if result.is_a?(Array)
                result.flat_map {|x| array_conversion.call(x)}
              else
                array_conversion.call(result)
              end
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
      parse_categories_as: AsteriskConfig::Category::Base,
      ssh_user: nil,
      ssh_identity_file: nil,
      ssh_kex_algorithm: nil
    )
      @file_path = file_path
      @host = host

      @parse_categories_as = parse_categories_as
      @ssh_options = {
        user: ssh_user,
        identity_file: ssh_identity_file,
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
            current_category = @parse_categories_as.new(category_name)
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
            current_category = @parse_categories_as.new(category_name)
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

      if @ssh_options[:identity_file]
        options.push("-i #{@ssh_options[:identity_file]}")
      end

      if @ssh_options[:kex_algorithm]
        options.push("-oKexAlgorithms=+#{@ssh_options[:kex_algorithm]}")
      end

      options.join(' ')
    end

    def ssh_destination
      if @ssh_options[:user]
        "#{@ssh_options[:user]}@#{@host}"
      else
        @host
      end
    end

    def raw_config
      if local?
        %x[cat #{@file_path}]
      else
        %x[#{ssh_bin} #{ssh_option_string} #{ssh_destination} "[[ -e #{@file_path} ]] && cat #{@file_path}"]
      end
    end

    def local?
      @host == 'localhost'
    end
  end
end
