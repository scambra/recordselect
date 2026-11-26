# frozen_string_literal: true

module RecordSelect
  module Conditions
    protected

    # returns the combination of all conditions.
    # conditions come from:
    # * current search (params[:search])
    # * intelligent url params (e.g. params[:first_name] if first_name is a model column)
    # * specific conditions supplied by the developer
    def record_select_conditions
      [
        record_select_conditions_from_search,
        *record_select_conditions_from_params,
        record_select_conditions_from_controller
      ].compact
    end

    # an override method.
    # here you can provide custom conditions to define the selectable records. useful for situational restrictions.
    def record_select_conditions_from_controller; end

    # another override method.
    # define any association includes you want for the finder search.
    def record_select_includes; end

    def record_select_like_operator
      @record_select_like_operator ||= ::ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' ? 'ILIKE' : 'LIKE'
    end

    # define special list of selected fields,
    # mainly to define extra fields that can be used for
    # specialized sorting.
    def record_select_select; end

    # generate conditions from params[:search]
    # override this if you want to customize the search routine
    def record_select_conditions_from_search
      return unless params[:search] && !params[:search].strip.empty?

      if full_text_search?
        tokens = params[:search].strip.split
        search_pattern = '%?%'
      else
        tokens = [params[:search].strip]
        search_pattern = '?%'
      end
      like_operator = record_select_config.like_operator || record_select_like_operator
      build_record_select_conditions(tokens, like_operator, search_pattern)
    end

    def full_text_search?
      (record_select_config.full_text_search? && params[:rs_mode].blank?) || params[:rs_mode] == 'contains'
    end

    def build_record_select_conditions(tokens, like_operator, search_pattern)
      columns = record_select_config.search_on
      return if columns.empty?

      where_clauses = columns.collect do |column|
        operator =
          if like_operator.respond_to?(:call)
            like_operator.call(column, record_select_config.model)
          else
            like_operator
          end
        "#{column} #{operator} ?"
      end
      phrase = "(#{where_clauses.join(' OR ')})"
      sql = ([phrase] * tokens.length).join(' AND ')

      values = tokens.collect { |token| [search_pattern.sub('?', token)] * columns.length }.flatten
      [sql, *values]
    end

    # generate conditions from the url parameters (e.g. users/browse?group_id=5)
    def record_select_conditions_from_params
      conditions = []
      ignored_columns = %w[controller action page search update]
      params.each do |field, value|
        next if field.in? ignored_columns
        next unless record_select_config.column_allowed?(field)

        column = record_select_config.model.columns_hash[field]
        next unless column

        conditions << record_select_condition_for_column(column, value)
      end
      conditions
    end

    def record_select_type_cast(column, value)
      if Rails.version < '4.2'
        column.type_cast value
      elsif Rails.version < '5.0'
        column.type_cast_from_user value
      elsif column.type.respond_to? :cast # jruby-jdbc and rails 5
        column.type.cast value
      else
        cast_type = ActiveModel::Type.lookup column.type
        cast_type ? cast_type.cast(value) : value
      end
    end

    # generates an SQL condition for the given column/value
    def record_select_condition_for_column(column, value)
      model = record_select_config.model
      if value.is_a? Array
        {column.name => value}
      elsif value.blank? && column.null
        {column.name => nil}
      elsif %i[string text].include? column.type
        column_name = "#{model.quoted_table_name}.#{model.connection.quote_column_name(column.name)}"
        ["LOWER(#{column_name}) LIKE ?", value]
      else
        {column.name => record_select_type_cast(column, value)}
      end
    end
  end
end
