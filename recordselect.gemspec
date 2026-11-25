# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'record_select/version'

Gem::Specification.new do |s|
  s.name = 'recordselect'
  s.version = RecordSelect::Version::STRING
  s.metadata['rubygems_mfa_required'] = 'true'

  s.required_ruby_version = '>= 3.2'
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['Sergio Cambra', 'Volker Hochstein', 'Lance Ivy']
  s.email = 'activescaffold@googlegroups.com'
  s.homepage = 'http://github.com/scambra/recordselect'
  s.summary = 'RecordSelect widget as a replacement for massive drop down lists'
  s.description = 'RecordSelect is a Rails widget to help you pick one record out of many. ' \
                  'I designed it as a more usable and performant alternative to generating a massive dropdown list'
  s.extra_rdoc_files = [
    'README'
  ]
  s.files = `git ls-files {app,config,lib,vendor}`.split("\n") + %w[MIT-LICENSE README]
  s.licenses = ['MIT']
  s.require_paths = ['lib']

  s.add_dependency('rails', ['>= 4.0.0'])
end
