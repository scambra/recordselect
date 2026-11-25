# frozen_string_literal: true

require_relative 'test_helper'
require 'action_controller'
require 'action_controller/test_case'
require 'action_view'
require 'active_model'
require 'record_select/config'
require 'record_select/actions'
require 'record_select/conditions'
require 'record_select/helpers/record_select_helper'
require 'record_select/extensions/localization'

class RecordSelectViewsTest < ActiveSupport::TestCase
  View = ActionView::Base.with_empty_template_cache
  Record = Struct.new(:id, :to_label)
  class Pager
    attr_accessor :count, :per_page

    def initialize(count, per_page)
      @count = count
      @per_page = per_page
    end
  end
  Page = Struct.new(:items, :pager, :number, :previous_page, :next_page) do
    def prev? = !previous_page.nil?
    def next? = !next_page.nil?
    def prev = previous_page
    def next = next_page
  end

  class Model
    extend ActiveModel::Naming
    extend ActiveModel::Translation
  end

  class Controller < ActionController::Base # rubocop:disable Rails/ApplicationController
    include RecordSelect

    record_select model: Model, search_on: :name
  end

  def setup
    @controller = Controller.new
    @controller.set_request!(ActionController::TestRequest.create(Controller))
    @controller.params = {controller: 'admin/users', action: 'browse', search: 'Alice', company_id: '3', secret: 'hidden', rs_mode: 'contains'}
    @config = RecordSelect::Config.new(Model, search_on: :name)
    @controller.define_singleton_method(:record_select_config) { @config_for_test }
    @controller.instance_variable_set(:@config_for_test, @config)
    @view = View.with_view_paths(File.expand_path('../app/views', __dir__), {}, @controller)
    @view.extend(RecordSelectHelper)
    @view.define_singleton_method(:url_for) do |options|
      options.is_a?(String) ? options : "/admin/users/browse?#{options.to_h.to_query}"
    end
    @view.define_singleton_method(:content_security_policy_nonce) { 'view-test-nonce' }
    @page = Page.new([Record.new(7, 'Alice <admin>'), Record.new(8, 'Bob')], Pager.new(30, 10), 2,
                     Page.new(nil, nil, 1), Page.new(nil, nil, 3))
    @view.assign(page: @page)
  end

  def configure(**options)
    @config = RecordSelect::Config.new(Model, {search_on: :name}.merge(options))
    @controller.instance_variable_set(:@config_for_test, @config)
  end

  def render_list
    Nokogiri::HTML.fragment(@view.render(partial: 'record_select/list', locals: {page: @page}))
  end

  def test_browse_renders_search_results_and_highlight_with_a_nonce
    html = Nokogiri::HTML.fragment(@view.render(partial: 'record_select/browse'))
    assert_equal 'record-select-admin_users', html.at_css('div.record-select')['id']
    assert_equal 'record-select-admin_users-search', html.at_css('form')['id']
    assert_equal(%w[rs7 rs8], html.css('li.record').pluck('id'))
    assert_equal 'view-test-nonce', html.at_css('script')['nonce']
    assert_includes html.at_css('script').text, 'rs.highlight(item)'
  end

  def test_list_escapes_labels_and_alternates_rows
    html = render_list
    assert_equal 'Alice <admin>', html.at_css('#rs7').text.strip
    assert_nil html.at_css('admin')
    assert_includes html.at_css('#rs7')['class'], 'odd'
    assert_includes html.at_css('#rs8')['class'], 'even'
  end

  def test_pagination_keeps_only_permitted_filters_and_the_search_mode
    configure(toggle_search_mode: true)
    @view.define_singleton_method(:permit_rs_browse_params) { [:company_id] }
    html = render_list
    previous = Rack::Utils.parse_nested_query(URI.parse(html.at_css('.previous a')['href']).query)
    following = Rack::Utils.parse_nested_query(URI.parse(html.at_css('.next a')['href']).query)
    assert_equal '1', previous['page']
    assert_equal '3', following['page']
    assert_equal 'Alice', following['search']
    assert_equal '3', following['company_id']
    assert_equal 'contains', following['rs_mode']
    assert_equal '1', following['update']
    assert_nil following['secret']
    assert_equal 'true', html.at_css('.next a')['data-remote']
  end

  def test_search_mode_link_switches_from_contains_to_begins
    configure(toggle_search_mode: true)
    link = render_list.at_css('a.rs-mode')
    assert_equal 'begins', link['data-value']
    assert_includes link['href'], 'rs_mode=begins'
  end

  def test_search_mode_link_switches_from_begins_to_contains
    configure(toggle_search_mode: true)
    @controller.params[:rs_mode] = 'begins'
    assert_equal 'contains', render_list.at_css('a.rs-mode')['data-value']
  end

  def test_single_page_omits_navigation_and_mode_toggle
    @page.previous_page = @page.next_page = nil
    html = render_list
    assert_empty html.css('li.pagination')
    assert_nil html.at_css('a.rs-mode')
    assert_nil html.at_css('ol')['class']
  end

  def test_unpaginated_results_are_scrollable_and_hide_next_page
    configure(pagination: false)
    @page.previous_page = nil
    html = render_list
    assert_equal 'scrollable', html.at_css('ol')['class']
    assert_nil html.at_css('.next')
  end

  def test_empty_results_render_the_summary_without_record_rows
    @page.items = []
    @page.pager.count = 0
    @page.previous_page = @page.next_page = nil
    html = render_list
    assert_not_nil html.at_css('li.found')['data-searching']
    assert_empty html.css('li.record')
  end

  def test_search_form_preserves_the_query_and_explicitly_allowed_filters
    configure(toggle_search_mode: true)
    @view.define_singleton_method(:permit_rs_browse_params) { [:company_id] }
    html = Nokogiri::HTML.fragment(@view.render(partial: 'record_select/search', locals: {controller: 'admin/users'}))
    form = html.at_css('form')
    query = Rack::Utils.parse_nested_query(URI.parse(form['action']).query)
    assert_equal 'get', form['method']
    assert_equal 'true', form['data-remote']
    assert_equal '1', query['page']
    assert_equal '1', query['update']
    assert_equal '3', query['company_id']
    assert_nil query['secret']
    assert_equal 'Alice', html.at_css('input[name=search]')['value']
    assert_equal 'off', html.at_css('input[name=search]')['autocomplete']
    assert_equal 'contains', html.at_css('input[name=rs_mode]')['value']
  end

  def test_search_form_omits_the_mode_when_disabled
    html = Nokogiri::HTML.fragment(@view.render(partial: 'record_select/search', locals: {controller: 'admin/users'}))
    assert_nil html.at_css('input[name=rs_mode]')
  end

  def test_ajax_template_escapes_rendered_html_and_highlights_results
    js = @view.render(template: 'record_select/browse', formats: [:js])
    assert_includes js, "RecordSelect.render_page('record-select-admin_users', '"
    assert_includes js, 'Alice &lt;admin&gt;'
    assert_includes js, '\\n'
    assert_includes js, 'rs.highlight(item)'
  end
end
