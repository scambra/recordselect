# frozen_string_literal: true

require 'active_support/deprecation'

module RecordSelect
  class << self
    attr_accessor :allowed_columns, :excluded_columns
  end
  self.allowed_columns = []
  self.excluded_columns = nil

  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new('4.2.0', 'RecordSelect')
  end

  def self.callback_registry?
    true
  end

  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    # Enables and configures RecordSelect on your controller.
    #
    # *Options*
    # +model+::     defaults based on the name of the controller
    # +per_page+::  records to show per page when browsing
    # +notify+::    a method name to invoke when a record has been selected.
    # +order_by+::  a SQL string to order the search results
    # +search_on+:: required searchable field or array of fields; [] disables the built-in text search
    # +allowed_columns+:: URL parameter filter columns; nil allows all model columns. Overrides RecordSelect.allowed_columns.
    # +excluded_columns+:: URL parameter filter columns to ignore, even if allowed. Overrides RecordSelect.excluded_columns.
    # +full_text_search+::  a boolean for whether to use a %?% search pattern or not. default is false.
    # +label+::     a proc that accepts a record as argument and returns an option label. default is to call record.to_label instead.
    # +include+::   as for ActiveRecord::Base#find. can help with search conditions or just help optimize rendering the results.
    # +link+::      a boolean for whether wrap the text returned by label in a link or not. default is true. set to false when
    #               label returns html code which can't be inside a tag. You can use record_select_link_to_select in your proc
    #               or partial to add a link to select action
    #
    # You may also pass a block, which will be used as options[:notify].
    def record_select(options = {})
      options[:model] ||= self.to_s.split('::').last.sub(/Controller$/, '').pluralize.singularize.underscore
      @record_select_config = RecordSelect::Config.new(options.delete(:model), options)
      self.send :include, RecordSelect::Actions
      self.send :include, RecordSelect::Conditions
    end

    def record_select_config
      case
      when defined?(@record_select_config)
        @record_select_config
      when superclass.respond_to?(:record_select_config)
        superclass.record_select_config
      end
    end

    def uses_record_select?
      !record_select_config.nil?
    end
  end
end
