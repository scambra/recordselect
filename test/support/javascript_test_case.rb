# frozen_string_literal: true

require_relative '../test_helper'
require 'capybara/minitest'
require 'selenium-webdriver'
require_relative 'javascript_app'

Capybara.register_driver :recordselect_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1200,900')
  options.binary = ENV['CHROME_BIN'] if ENV['CHROME_BIN']
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
Capybara.server = :puma, {Silent: true}
Capybara.default_max_wait_time = 5

module RecordSelectJavascript
  class TestCase < ActiveSupport::TestCase
    include Capybara::Minitest::Assertions

    def page
      @page ||= self.class.session
    end

    def self.session
      @session ||= Capybara::Session.new(:recordselect_chrome, App.new)
    end

    def setup
      page.visit('/')
      assert_selector 'html[data-recordselect-ready="true"]'
    end

    def teardown
      return unless @page

      assert_empty page.evaluate_script('window.testErrors'), 'Browser reported a JavaScript error'
    ensure
      @page&.visit('about:blank')
    end

    def open_widget(id = 'single')
      page.find("##{id}").click
      assert_selector '.record-select-container #rs7'
    end

    def evaluate(script)
      page.evaluate_script(script)
    end

    def execute(script)
      page.execute_script(script)
    end

    def instance(id = 'single')
      "jQuery('.record-select-container').filter(function() { return jQuery(this).data('recordselect').obj.attr('id') === #{id.to_json}; }).data('recordselect')"
    end
  end
end
