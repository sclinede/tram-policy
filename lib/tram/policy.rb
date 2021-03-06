require "dry-initializer"
require "i18n"

module Tram
  # Base class for policy objects with composable validation errors
  class Policy
    require_relative "policy/validation_error"
    require_relative "policy/inflector"
    require_relative "policy/error"
    require_relative "policy/errors"
    require_relative "policy/validator"

    extend Dry::Initializer

    class << self
      # Registers a validator
      #
      # @param  [#to_sym, Array<#to_sym>] names
      # @option opts [Boolean] :stop_on_failure
      # @return [self]
      #
      def validate(name = nil, **opts, &block)
        local << Validator.new(scope, name, block, opts)
        self
      end

      # Policy constructor/validator (alias for [.new])
      #
      # @param  [Object] *args
      # @return [Tram::Policy]
      #
      def [](*args)
        new(*args)
      end

      private

      def scope
        @scope ||= ["tram-policy", *Inflector.underscore(name)]
      end

      def local
        @local ||= []
      end

      def all
        ((self == Tram::Policy) ? [] : superclass.send(:all)) + local
      end
    end

    # Translates a message in the scope of current policy
    #
    # @param  [#to_s] message
    # @param  [Hash<Symbol, Object>] options
    # @return [String]
    #
    def t(message, **options)
      return message.to_s unless message.is_a? Symbol
      I18n.t message, options.merge(scope: @__scope__)
    end

    # Collection of validation errors
    #
    # @return [Tram::Policy::Errors]
    #
    def errors
      @errors ||= Errors.new(self)
    end

    # Checks whether the policy is valid
    #
    # @param  [Proc, nil] filter Block describing **errors to be skipped**
    # @return [Boolean]
    #
    def valid?(&filter)
      filter ? errors.reject(&filter).empty? : errors.empty?
    end

    # Checks whether the policy is invalid
    #
    # @param  [Proc, nil] filter Block describing **the only errors to count**
    # @return [Boolean]
    #
    def invalid?(&filter)
      filter ? errors.any?(&filter) : errors.any?
    end

    # Raises exception if the policy is not valid
    #
    # @param  (see #valid?)
    # @raise  [Tram::Policy::ValidationError] if the policy isn't valid
    # @return [nil] if the policy is valid
    #
    def validate!(&filter)
      raise ValidationError.new(self, filter) unless valid?(&filter)
    end

    # Human-readable representation of the policy
    #
    # @example Displays policy name and its attributes
    #   UserPolicy[name: "Andy"].inspect
    #   # => #<UserPolicy["name" => "Andy"]>
    #
    # @return [String]
    #
    def inspect
      "#<#{self.class.name}[#{@__options__}]>"
    end

    private

    def initialize(*)
      super
      self.class.send(:all).each do |validator|
        size = errors.count
        validator.check(self)
        break if (errors.count > size) && validator.stop_on_failure
      end
    end
  end
end
