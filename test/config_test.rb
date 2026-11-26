# frozen_string_literal: true

require_relative 'test_helper'
require 'active_support/core_ext/object/inclusion'
require 'record_select'
require 'record_select/config'
require 'record_select/conditions'

class RecordSelectConfigTest < ActiveSupport::TestCase
  class Model
    def self.table_name = 'members'
    def self.primary_key = 'uuid'
  end

  class FilterController
    include RecordSelect::Conditions

    attr_accessor :params, :record_select_config

    def filters
      record_select_conditions_from_params
    end

    def text_conditions
      build_record_select_conditions(['alice'], 'LIKE', '?%')
    end

    def record_select_condition_for_column(column, value)
      {column.name => value}
    end
  end

  def setup
    @like_operator = RecordSelect.like_operator
    @allowed_columns = RecordSelect.allowed_columns
    @excluded_columns = RecordSelect.excluded_columns
    RecordSelect.like_operator = nil
    RecordSelect.allowed_columns = nil
    RecordSelect.excluded_columns = []
  end

  def teardown
    RecordSelect.like_operator = @like_operator
    RecordSelect.allowed_columns = @allowed_columns
    RecordSelect.excluded_columns = @excluded_columns
  end

  def config(options = {})
    RecordSelect::Config.new(Model, {search_on: [:name]}.merge(options))
  end

  def controller(options = {})
    instance = FilterController.new
    instance.record_select_config = config(options)
    columns = %w[id name company_id password_digest action].index_with { |name| Struct.new(:name).new(name) }
    model = Struct.new(:columns_hash).new(columns)
    instance.record_select_config.define_singleton_method(:model) { model }
    instance.params = {'id' => '1', 'company_id' => '2', 'password_digest' => 'secret', 'action' => 'browse', 'unknown' => 'ignored'}
    instance
  end

  def test_search_on_is_required
    error = assert_raise(ArgumentError) { RecordSelect::Config.new('user') }
    assert_match(/requires :search_on/, error.message)
    assert_raise(ArgumentError) { config(search_on: nil) }
  end

  def test_search_on_accepts_a_field_or_an_explicit_empty_array
    assert_equal [:name], config(search_on: :name).search_on
    assert_equal [], config(search_on: []).search_on
    assert_nil controller(search_on: []).text_conditions
  end

  def test_text_search_preserves_explicit_fields
    assert_equal ['(name LIKE ? OR email LIKE ?)', 'alice%', 'alice%'], controller(search_on: %i[name email]).text_conditions
  end

  def test_like_operator_defaults_to_the_adapter_operator
    assert_nil config.like_operator
  end

  def test_global_like_operator_is_captured_at_configuration_time
    pattern = ->(column, _model) { column == :name ? 'ILIKE' : 'LIKE' }
    RecordSelect.like_operator = pattern
    instance = config
    RecordSelect.like_operator = 'LIKE'

    assert_same pattern, instance.like_operator
  end

  def test_controller_like_operator_overrides_the_global_setting
    RecordSelect.like_operator = 'ILIKE'
    assert_equal 'LIKE', config(like_operator: 'LIKE').like_operator
    pattern = ->(_column, _model) { 'LIKE' }
    assert_same pattern, config(like_operator: pattern).like_operator
    assert_nil config(like_operator: nil).like_operator
  end

  def test_default_filters_preserve_model_columns_and_ignore_reserved_and_unknown_parameters
    assert_equal [{'id' => '1'}, {'company_id' => '2'}, {'password_digest' => 'secret'}], controller.filters
  end

  def test_global_allowed_columns_limit_filters
    RecordSelect.allowed_columns = [:company_id]
    assert_equal [{'company_id' => '2'}], controller.filters
  end

  def test_global_exclusions_limit_filters
    RecordSelect.excluded_columns = [:password_digest, 'id']
    assert_equal [{'company_id' => '2'}], controller.filters
  end

  def test_controller_options_override_global_lists_and_exclusions_win
    RecordSelect.allowed_columns = [:password_digest]
    RecordSelect.excluded_columns = [:company_id]
    instance = controller(allowed_columns: [:id, 'company_id'], excluded_columns: ['id'])
    assert_equal [{'company_id' => '2'}], instance.filters
  end

  def test_overriding_one_list_preserves_the_other_global_default
    RecordSelect.excluded_columns = [:id]
    assert_equal [{'company_id' => '2'}], controller(allowed_columns: %i[id company_id]).filters
  end

  def test_explicit_nil_and_empty_exclusions_clear_global_restrictions
    RecordSelect.allowed_columns = []
    RecordSelect.excluded_columns = [:company_id]
    assert_equal [{'id' => '1'}, {'company_id' => '2'}, {'password_digest' => 'secret'}], controller(allowed_columns: nil, excluded_columns: []).filters
  end

  def test_empty_allowed_columns_disable_parameter_filters
    assert_equal [], controller(allowed_columns: []).filters
  end

  def test_default_policy_disables_parameter_filters_without_explicit_configuration
    assert_equal [], @allowed_columns
    assert_equal [], @excluded_columns
    RecordSelect.allowed_columns = @allowed_columns
    RecordSelect.excluded_columns = @excluded_columns

    assert_equal [], controller.filters
  end

  def test_nil_global_exclusions_are_normalized_without_enabling_filters
    RecordSelect.allowed_columns = []
    RecordSelect.excluded_columns = nil

    assert_equal [], config.excluded_columns
    assert_equal [], controller.filters
    assert_equal [{'company_id' => '2'}], controller(allowed_columns: [:company_id]).filters
  end

  def test_explicit_nil_exclusions_clear_global_exclusions
    RecordSelect.excluded_columns = [:company_id]
    instance = controller(allowed_columns: [:company_id], excluded_columns: nil)

    assert_equal [], instance.record_select_config.excluded_columns
    assert_equal [{'company_id' => '2'}], instance.filters
  end

  def test_global_settings_are_captured_when_the_controller_is_configured
    RecordSelect.allowed_columns = %i[id company_id]
    RecordSelect.excluded_columns = :id
    instance = controller
    RecordSelect.allowed_columns = []
    RecordSelect.excluded_columns = [:company_id]

    assert_equal %w[id company_id], instance.record_select_config.allowed_columns
    assert_equal ['id'], instance.record_select_config.excluded_columns
    assert_equal [{'company_id' => '2'}], instance.filters
  end

  def test_normalized_settings_do_not_share_the_source_arrays
    allowed = [:id, 'company_id']
    excluded = [:id]
    instance = controller(allowed_columns: allowed, excluded_columns: excluded)
    allowed.clear
    excluded << :company_id

    assert_equal [{'company_id' => '2'}], instance.filters
  end

  def test_parameter_restrictions_do_not_limit_text_search
    instance = controller(allowed_columns: [], excluded_columns: [:name])
    assert_equal ['(name LIKE ?)', 'alice%'], instance.text_conditions
  end

  def test_model_resolution_and_default_order_use_the_models_primary_key
    instance = config
    assert_same Model, instance.model
    assert_same instance.model, instance.model
    assert_equal 'members.uuid ASC', instance.order_by
  end

  def test_default_pagination_and_search_settings
    instance = config
    assert_equal 10, instance.per_page
    assert instance.pagination?
    assert_not instance.full_text_search?
    assert_not instance.toggle_search_mode?
    assert_nil instance.notify
    assert_equal [:name], instance.search_on
  end

  def test_explicit_settings_and_associations_are_preserved
    instance = config(per_page: 25, pagination: false, full_text_search: true, toggle_search_mode: true,
                      order_by: 'name DESC', notify: :selected, include: :company, joins: :roles, left_joins: :team)
    assert_equal 25, instance.per_page
    assert_not instance.pagination?
    assert instance.full_text_search?
    assert instance.toggle_search_mode?
    assert_equal 'name DESC', instance.order_by
    assert_equal :selected, instance.notify
    assert_equal :company, instance.include
    assert_equal :roles, instance.joins
    assert_equal :team, instance.left_joins
  end

  def test_ordering_can_be_disabled
    assert_nil config(order_by: false).order_by
  end

  def test_default_label_and_custom_renderers
    record = Struct.new(:to_label).new('Alice')
    assert_equal 'Alice', config.label.call(record)
    renderer = proc { |item| "Member #{item.to_label}" }
    assert_same renderer, config(label: renderer).label
    assert_equal :member, config(label: :member).label
    assert_equal 'member', config(label: 'member').label
  end

  def test_nested_search_fields_are_flattened
    assert_equal %i[name email], config(search_on: [:name, [:email]]).search_on
  end

  def test_column_policy_accepts_symbols_and_exclusions_win
    instance = config(allowed_columns: :name, excluded_columns: 'name')
    assert_not instance.column_allowed?(:name)
    assert_not instance.column_allowed?('email')
    assert config(allowed_columns: nil).column_allowed?(:email)
  end
end
