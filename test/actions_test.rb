# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'
require 'active_support/core_ext/hash/indifferent_access'
require 'record_select/actions'
require 'record_select/conditions'
require 'record_select/config'

class RecordSelectActionsTest < ActiveSupport::TestCase
  class Relation
    attr_accessor :total
    attr_reader :calls, :records

    def initialize
      @calls = []
      @records = [Struct.new(:id).new(7)]
      @total = 21
    end

    %i[includes references joins distinct left_joins where select limit offset order].each do |method|
      define_method(method) do |*args|
        @calls << [method, *args]
        self
      end
    end

    def count
      @calls << [:count]
      total
    end

    def to_a = records

    def find(id)
      @calls << [:find, id]
      records.first
    end
  end

  class Controller
    include RecordSelect

    record_select model: 'user', search_on: []
    attr_accessor :params, :config, :relation, :format
    attr_reader :rendered, :selected

    def record_select_config = config
    def record_select_model = relation
    def record_select_conditions = [{active: true}, ['name LIKE ?', 'A%']]
    def render(options) = @rendered = options
    def selected_record(record) = @selected = record

    def respond_to
      requested_format = format || :html
      collector = Object.new
      %i[html js].each do |name|
        collector.define_singleton_method(name) { |&block| block.call if name == requested_format }
      end
      collector.define_singleton_method(:any) do |*formats, &block|
        block.call if formats.include?(requested_format)
      end
      yield collector
    end
  end

  # RecordSelect delegates pagination to a host-provided Paginator.
  class PaginationAdapter
    attr_reader :count, :per_page

    def initialize(count, per_page, &fetch)
      @count = count
      @per_page = per_page
      @fetch = fetch
    end

    def page(number)
      Struct.new(:items, :number, :pager).new(@fetch.call((number.to_i - 1) * per_page, per_page), number, self)
    end
  end

  def setup
    @controller = Controller.new
    @controller.params = {}.with_indifferent_access
    @controller.config = RecordSelect::Config.new('user', search_on: [], order_by: 'name ASC')
    @controller.relation = Relation.new
  end

  def test_query_applies_each_condition
    assert_same @controller.relation, @controller.send(:record_select_query)
    assert_equal [[:where, {active: true}], [:where, ['name LIKE ?', 'A%']]], @controller.relation.calls
  end

  def test_query_applies_includes_references_and_join_options
    @controller.config = RecordSelect::Config.new('user', search_on: [], joins: :roles, left_joins: :team)
    @controller.define_singleton_method(:record_select_includes) { [:company] }
    @controller.send(:record_select_query)
    assert_equal [[:includes, [:company]], [:references, [:company]], %i[joins roles], [:distinct], %i[left_joins team]], @controller.relation.calls.first(5)
  end

  def test_browse_fetches_a_page_with_limit_offset_and_order
    @controller.params[:page] = '2'
    browse
    page = @controller.instance_variable_get(:@page)
    assert_equal @controller.relation.records, page.items
    assert_equal 21, page.pager.count
    assert_includes @controller.relation.calls, [:limit, 10]
    assert_includes @controller.relation.calls, [:offset, 10]
    assert_includes @controller.relation.calls, [:order, 'name ASC']
    assert_equal({partial: 'record_select/browse'}, @controller.rendered)
  end

  def test_browse_defaults_to_first_page_and_supports_grouped_counts_and_selected_fields
    @controller.relation.total = {'one' => 3, 'two' => 4}
    @controller.define_singleton_method(:record_select_select) { 'users.*, rank' }
    browse
    page = @controller.instance_variable_get(:@page)
    assert_equal 1, page.number
    assert_equal 2, page.pager.count
    assert_includes @controller.relation.calls, [:select, 'users.*, rank']
    assert_includes @controller.relation.calls, [:offset, 0]
  end

  def test_browse_without_pagination_does_not_count_or_limit_results
    @controller.config = RecordSelect::Config.new('user', search_on: [], pagination: false, include: :company, order_by: false)
    browse
    assert_equal @controller.relation.records, @controller.instance_variable_get(:@page).items
    pagination_methods = %i[count limit offset]
    assert_empty(@controller.relation.calls.select { |call| pagination_methods.include?(call.first) })
    assert_includes @controller.relation.calls, %i[includes company]
    assert_includes @controller.relation.calls, [:order, nil]
  end

  def test_javascript_response_uses_template_only_for_updates
    @controller.format = :js
    @controller.send(:record_select_browse_response)
    assert_equal({partial: 'record_select/browse'}, @controller.rendered)
    @controller.params[:update] = '1'
    @controller.send(:record_select_browse_response)
    assert_equal({template: 'record_select/browse'}, @controller.rendered)
  end

  def test_data_formats_use_default_rendering
    %i[json xml yaml].each do |format|
      @controller.format = format
      @controller.send(:record_select_browse_response)
      assert_nil @controller.rendered
    end
  end

  def test_render_helper_prefixes_templates_and_can_yield_to_views
    options = @controller.send(:render_record_select, partial: 'list', locals: {page: 1}) { |value| value }
    assert_equal({partial: 'record_select/list', locals: {page: 1}}, options)
    @controller.send(:render_record_select, template: 'browse')
    assert_equal({template: 'record_select/browse'}, @controller.rendered)
  end

  def test_select_finds_the_record_and_calls_a_proc
    selected = []
    @controller.config = RecordSelect::Config.new('user', search_on: [], notify: proc { |record| selected << record })
    @controller.params[:id] = '7'
    @controller.select
    assert_equal @controller.relation.records, selected
    assert_equal [[:find, '7']], @controller.relation.calls
    assert_equal({nothing: true}, @controller.rendered)
  end

  def test_select_calls_a_named_callback
    @controller.config = RecordSelect::Config.new('user', search_on: [], notify: :selected_record)
    @controller.select
    assert_same @controller.relation.records.first, @controller.selected
  end

  def test_select_without_callback_still_renders
    @controller.select
    assert_nil @controller.selected
    assert_equal({nothing: true}, @controller.rendered)
  end

  def test_record_select_model_delegates_to_configuration
    controller = Class.new { include RecordSelect }.new
    config = Struct.new(:model).new(String)
    controller.define_singleton_method(:record_select_config) { config }
    assert_same String, controller.record_select_model
  end

  private

  def browse
    original = Object.const_get(:Paginator) if Object.const_defined?(:Paginator)
    Object.send(:remove_const, :Paginator) if original
    Object.const_set(:Paginator, PaginationAdapter)
    @controller.browse
  ensure
    Object.send(:remove_const, :Paginator)
    Object.const_set(:Paginator, original) if original
  end
end
