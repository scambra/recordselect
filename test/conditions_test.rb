# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'
require 'active_support/core_ext/hash/indifferent_access'
require 'rails'
require 'active_record'
require 'active_support/core_ext/object/inclusion'
require 'record_select/config'
require 'record_select/conditions'

class RecordSelectConditionsTest < ActiveSupport::TestCase
  Column = Struct.new(:name, :type, :null)

  class Controller
    include RecordSelect::Conditions

    attr_accessor :params, :record_select_config
  end

  def setup
    @controller = Controller.new
    @controller.params = {}.with_indifferent_access
    @controller.record_select_config = RecordSelect::Config.new('user', search_on: %w[name email])
    connection = Object.new
    connection.define_singleton_method(:quote_column_name) { |name| "\"#{name}\"" }
    model = Struct.new(:quoted_table_name, :connection).new('"users"', connection)
    @controller.record_select_config.define_singleton_method(:model) { model }
  end

  def conditions(method = :record_select_conditions_from_search, *)
    @controller.send(method, *)
  end

  def search(text, mode: nil, full_text: false)
    @controller.params = {search: text, rs_mode: mode}.with_indifferent_access
    @controller.record_select_config = RecordSelect::Config.new('user', search_on: %w[name email], full_text_search: full_text)
    @controller.instance_variable_set(:@record_select_like_operator, 'LIKE')
    conditions
  end

  def test_missing_and_whitespace_searches_add_no_condition
    [nil, '', " \t\n"].each { |text| assert_nil search(text) }
  end

  def test_prefix_search_keeps_a_phrase_and_binds_values_for_each_field
    assert_equal ['(name LIKE ? OR email LIKE ?)', "O'Reilly Smith%", "O'Reilly Smith%"], search("  O'Reilly Smith  ")
  end

  def test_full_text_search_requires_every_word_to_match_at_least_one_field
    assert_equal ['(name LIKE ? OR email LIKE ?) AND (name LIKE ? OR email LIKE ?)', '%Alice%', '%Alice%', '%Smith%', '%Smith%'], search(" Alice\tSmith ", full_text: true)
  end

  def test_explicit_search_mode_overrides_the_configuration
    assert_equal ['(name LIKE ? OR email LIKE ?)', 'Alice Smith%', 'Alice Smith%'], search('Alice Smith', mode: 'begins', full_text: true)
    assert_equal ['(name LIKE ? OR email LIKE ?)', '%Alice%', '%Alice%'], search('Alice', mode: 'contains')
  end

  def test_empty_search_fields_disable_text_conditions
    @controller.params[:search] = 'Alice'
    @controller.record_select_config = RecordSelect::Config.new('user', search_on: [])
    @controller.instance_variable_set(:@record_select_like_operator, 'LIKE')
    assert_nil conditions
  end

  def test_configured_operator_is_used_without_an_adapter_connection
    @controller.params[:search] = "O'Reilly"
    @controller.record_select_config = RecordSelect::Config.new('user', search_on: %w[name email], like_operator: 'ILIKE')

    assert_equal ['(name ILIKE ? OR email ILIKE ?)', "O'Reilly%", "O'Reilly%"], conditions
  end

  def test_callable_operator_receives_each_column_and_model_once_for_multiple_tokens
    columns = [:name, 'users.email']
    received = []
    model = Class.new
    pattern = lambda do |column, configured_model|
      received << [column, configured_model]
      column == :name ? 'ILIKE' : 'LIKE'
    end
    @controller.params[:search] = 'Alice Smith'
    @controller.record_select_config = RecordSelect::Config.new('user', search_on: columns, full_text_search: true, like_operator: pattern)

    @controller.record_select_config.define_singleton_method(:model) { model }

    assert_equal ['(name ILIKE ? OR users.email LIKE ?) AND (name ILIKE ? OR users.email LIKE ?)', '%Alice%', '%Alice%', '%Smith%', '%Smith%'], conditions
    assert_equal columns.map { |column| [column, model] }, received
  end

  def test_global_callable_can_choose_an_operator_from_model_column_collation
    previous_operator = RecordSelect.like_operator
    RecordSelect.like_operator = lambda do |column, model|
      model.columns_hash.fetch(column.to_s).collation == 'case_insensitive' ? 'LIKE' : 'ILIKE'
    end
    column_type = Struct.new(:collation)
    columns = {'name' => column_type.new('case_sensitive'), 'email' => column_type.new('case_insensitive')}
    model = Class.new
    model.define_singleton_method(:columns_hash) { columns }
    @controller.params[:search] = 'Alice'
    @controller.record_select_config = RecordSelect::Config.new('user', search_on: %i[name email])
    @controller.record_select_config.define_singleton_method(:model) { model }

    assert_equal ['(name ILIKE ? OR email LIKE ?)', 'Alice%', 'Alice%'], conditions
  ensure
    RecordSelect.like_operator = previous_operator
  end

  def test_empty_search_fields_do_not_call_the_pattern
    pattern = ->(_column, _model) { flunk 'empty search fields must not call the pattern' }
    @controller.params[:search] = 'Alice'
    @controller.record_select_config = RecordSelect::Config.new('user', search_on: [], like_operator: pattern)

    assert_nil conditions
  end

  def test_adapter_controls_case_insensitive_search
    %w[PostgreSQL SQLite MySQL].each do |adapter|
      controller = Controller.new
      connection = Struct.new(:adapter_name).new(adapter)
      ActiveRecord::Base.stub(:connection, connection) do
        assert_equal(adapter == 'PostgreSQL' ? 'ILIKE' : 'LIKE', controller.send(:record_select_like_operator))
      end
    end
  end

  def test_conditions_combine_search_parameter_filters_and_controller_scope
    @controller.define_singleton_method(:record_select_conditions_from_search) { ['name LIKE ?', 'A%'] }
    @controller.define_singleton_method(:record_select_conditions_from_params) { [{company_id: 3}] }
    @controller.define_singleton_method(:record_select_conditions_from_controller) { {active: true} }
    assert_equal [['name LIKE ?', 'A%'], {company_id: 3}, {active: true}], conditions(:record_select_conditions)
  end

  def test_default_hooks_add_no_scope_includes_or_select
    assert_equal [], conditions(:record_select_conditions)
    assert_nil conditions(:record_select_includes)
    assert_nil conditions(:record_select_select)
  end

  def test_array_filters_preserve_all_values
    assert_equal({'id' => %w[1 2]}, column_condition(Column.new('id', :integer, false), %w[1 2]))
  end

  def test_blank_nullable_filters_become_null
    [nil, '', ' '].each do |value|
      assert_equal({'name' => nil}, column_condition(Column.new('name', :string, true), value))
    end
  end

  def test_string_and_text_filters_quote_identifiers_and_bind_the_value
    %i[string text].each do |type|
      assert_equal ['LOWER("users"."name") LIKE ?', "a' OR 1=1"], column_condition(Column.new('name', type, false), "a' OR 1=1")
    end
  end

  def test_non_string_filters_use_active_model_casts
    assert_equal({'id' => 12}, column_condition(Column.new('id', :integer, false), '12'))
    assert_equal({'active' => false}, column_condition(Column.new('active', :boolean, false), '0'))
  end

  def test_jdbc_columns_use_their_own_cast_type
    type = ActiveModel::Type::Integer.new
    assert_equal 42, conditions(:record_select_type_cast, Column.new('id', type, false), '42')
  end

  def test_legacy_rails_column_casting
    column = Object.new
    column.define_singleton_method(:type_cast) { |value| [:legacy, value] }
    column.define_singleton_method(:type_cast_from_user) { |value| [:user, value] }
    Rails.stub(:version, '4.1') do
      assert_equal [:legacy, '7'], conditions(:record_select_type_cast, column, '7')
    end
    Rails.stub(:version, '4.2') do
      assert_equal [:user, '7'], conditions(:record_select_type_cast, column, '7')
    end
  end

  def test_missing_cast_type_preserves_the_value
    ActiveModel::Type.stub(:lookup, nil) do
      assert_equal 'value', conditions(:record_select_type_cast, Column.new('custom', :custom, false), 'value')
    end
  end

  private

  def column_condition(column, value)
    conditions(:record_select_condition_for_column, column, value)
  end
end
