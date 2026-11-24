# frozen_string_literal: true

require 'test/unit'
require 'minitest/autorun'
require 'active_support'
require 'active_support/test_case'
require 'active_support/core_ext/object/inclusion'
require 'record_select'
require 'record_select/config'
require 'record_select/conditions'

class RecordSelectConfigurationTest < ActiveSupport::TestCase
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
    @allowed_columns = RecordSelect.allowed_columns
    @excluded_columns = RecordSelect.excluded_columns
    RecordSelect.allowed_columns = nil
    RecordSelect.excluded_columns = []
  end

  def teardown
    RecordSelect.allowed_columns = @allowed_columns
    RecordSelect.excluded_columns = @excluded_columns
  end

  def config(options = {})
    RecordSelect::Config.new('user', {search_on: [:name]}.merge(options))
  end

  def controller(options = {})
    instance = FilterController.new
    instance.record_select_config = config(options)
    columns = %w[id name company_id password_digest action].to_h { |name| [name, Struct.new(:name).new(name)] }
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
    assert_equal ['(name LIKE ? OR email LIKE ?)', 'alice%', 'alice%'], controller(search_on: [:name, :email]).text_conditions
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
    assert_equal [{'company_id' => '2'}], controller(allowed_columns: [:id, :company_id]).filters
  end

  def test_explicit_nil_and_empty_exclusions_clear_global_restrictions
    RecordSelect.allowed_columns = []
    RecordSelect.excluded_columns = [:company_id]
    assert_equal [{'id' => '1'}, {'company_id' => '2'}, {'password_digest' => 'secret'}], controller(allowed_columns: nil, excluded_columns: []).filters
  end

  def test_empty_allowed_columns_disable_parameter_filters
    assert_equal [], controller(allowed_columns: []).filters
  end

  def test_defaults_leave_both_column_policies_unconfigured
    assert_nil @allowed_columns
    assert_nil @excluded_columns
    RecordSelect.excluded_columns = nil
    assert_nil config.allowed_columns
    assert_nil config.excluded_columns
  end

  def test_explicit_nil_exclusions_override_global_exclusions_and_warn
    RecordSelect.excluded_columns = [:password_digest]
    instance = controller(excluded_columns: nil)
    warnings = capture_filter_warnings { assert_equal 3, instance.filters.length }
    assert_equal 1, warnings.length
  end

  def test_unconfigured_filters_warn_each_time_filters_are_built
    RecordSelect.excluded_columns = nil
    instance = controller
    warnings = capture_filter_warnings do
      assert_equal 3, instance.filters.length
      instance.filters
    end
    assert_equal 2, warnings.length
    assert_match(/allowed_columns/, warnings.first)
    assert_match(/excluded_columns/, warnings.first)
  end

  def test_unconfigured_filters_do_not_warn_for_reserved_or_unknown_parameters
    RecordSelect.excluded_columns = nil
    instance = controller
    instance.params = {'action' => 'browse', 'unknown' => 'ignored'}
    assert_empty capture_filter_warnings { assert_equal [], instance.filters }
  end

  def test_explicit_filter_policies_do_not_warn
    RecordSelect.excluded_columns = nil
    [{allowed_columns: []}, {allowed_columns: [:company_id]},
     {excluded_columns: []}, {excluded_columns: [:password_digest]}].each do |options|
      assert_empty capture_filter_warnings { controller(options).filters }
    end
  end

  def test_global_explicit_compatibility_does_not_warn
    RecordSelect.allowed_columns = nil
    RecordSelect.excluded_columns = []
    assert_empty capture_filter_warnings { assert_equal 3, controller.filters.length }
  end

  def test_global_settings_are_captured_when_the_controller_is_configured
    RecordSelect.allowed_columns = [:id, :company_id]
    RecordSelect.excluded_columns = :id
    instance = controller
    RecordSelect.allowed_columns = []
    RecordSelect.excluded_columns = [:company_id]

    assert_equal ['id', 'company_id'], instance.record_select_config.allowed_columns
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

  private

  def capture_filter_warnings
    deprecator = RecordSelect.deprecator
    original_behavior = deprecator.behavior
    original_silenced = deprecator.silenced
    warnings = []
    deprecator.silenced = false
    deprecator.behavior = proc { |message, *| warnings << message }
    yield
    warnings
  ensure
    deprecator.behavior = original_behavior
    deprecator.silenced = original_silenced
  end
end
