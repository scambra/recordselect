# frozen_string_literal: true

if ENV['COVERAGE'] == 'true'
  require 'simplecov'
  SimpleCov.start
end

require 'minitest/autorun'
require 'active_support'
require 'active_support/test_case'
require 'record_select'
