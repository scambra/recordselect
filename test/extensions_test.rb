# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'
require 'rails'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_record'
require 'recordselect'

class RecordSelectExtensionsTest < ActiveSupport::TestCase
  class Model < ActiveRecord::Base
    self.abstract_class = true
    def to_s = 'Member description'
  end

  def test_active_record_falls_back_to_to_s_for_labels
    assert_equal 'Member description', Model.allocate.to_label
  end

  def test_existing_model_labels_take_precedence
    klass = Class.new(Model) { def to_label = 'Custom label' }
    assert_equal 'Custom label', klass.allocate.to_label
  end

  def test_localization_translates_in_record_select_scope_and_accepts_interpolation
    # I18n interpolation uses template tokens rather than Ruby format tokens.
    I18n.backend.store_translations(:en, record_select: {test_greeting: 'Hello %{name}'}) # rubocop:disable Style/FormatStringToken
    assert_equal 'Hello Alice', Object.new.rs_(:test_greeting, name: 'Alice', locale: :en)
  end

  def test_localization_falls_back_for_unknown_strings_symbols_and_blank_keys
    assert_equal 'Test Unknown Label', Object.new.rs_(:test_unknown_label)
    assert_equal 'Custom label', Object.new.rs_('Custom label')
    assert_equal '', Object.new.rs_('')
    assert_nil Object.new.rs_(nil)
  end

  def test_localization_options_override_the_default_scope
    I18n.backend.store_translations(:en, test_other_scope: {test_greeting: 'Other scope'})
    assert_equal 'Other scope', Object.new.rs_(:test_greeting, scope: :test_other_scope, locale: :en)
  end

  def test_routes_add_only_a_collection_get_for_browse
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      resources :users do
        record_select_routes
      end
    end
    assert_equal '/users/browse', routes.url_helpers.browse_users_path
    browse = routes.routes.select { |route| route.defaults[:action] == 'browse' }
    assert_equal 1, browse.length
    assert_equal 'GET', browse.first.verb
    assert_equal 'users', browse.first.defaults[:controller]
  end

  def test_engine_initializers_install_controller_and_view_extensions
    engine = RecordSelect::Engine.instance
    %w[recordselect.action_controller record_select.action_view].each do |name|
      engine.initializers.find { |initializer| initializer.name == name }.run(nil)
    end
    assert_includes ActionController::Base.ancestors, RecordSelect
    assert_includes ActionView::Base.ancestors, RecordSelectHelper
    assert_includes ActionView::Helpers::FormBuilder.ancestors, RecordSelect::FormBuilder
  end

  def test_engine_registers_pagination_images
    engine = RecordSelect::Engine.instance
    assets = ActiveSupport::OrderedOptions.new
    assets.precompile = []
    engine.stub(:config, Struct.new(:assets).new(assets)) do
      engine.initializers.find { |initializer| initializer.name == 'record_select.assets' }.run(nil)
    end
    assert_equal %w[record_select/next.gif record_select/previous.gif], assets.precompile
  end
end
