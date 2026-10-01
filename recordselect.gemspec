# frozen_string_literal: true
# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'record_select/version'

Gem::Specification.new do |s|
  s.name = %q{recordselect}
  s.version = RecordSelect::Version::STRING

  s.required_ruby_version = '>= 1.9'
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Sergio Cambra", "Volker Hochstein", "Lance Ivy"]
  s.email = %q{activescaffold@googlegroups.com}
  s.homepage = %q{http://github.com/scambra/recordselect}
  s.summary = %q{RecordSelect widget as a replacement for massive drop down lists}
  s.description = %q{RecordSelect is a Rails widget to help you pick one record out of many. I designed it as a more usable and performant alternative to generating a massive dropdown list}
  s.extra_rdoc_files = [
    "README"
  ]
  s.files = `git ls-files {app,config,lib,vendor}`.split("\n") + %w[MIT-LICENSE README]
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.test_files = `git ls-files test`.split("\n")

  s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
  s.add_runtime_dependency(%q<rails>, [">= 4.0.0"])
  s.required_ruby_version = '>= 1.9.1'
end
