# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "zeevex_threadsafe/version"

Gem::Specification.new do |s|
  s.name        = "zeevex_threadsafe"
  s.version     = ZeevexThreadsafe::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Robert Sanders"]
  s.email       = ["robert@zeevex.com"]
  s.homepage    = "http://github.com/zeevex/zeevex_threadsafe"
  s.summary     = %q{Utilities to help in creating thread-safe apps}
  s.description = %q{Utilities to help in creating thread-safe apps}

  s.rubyforge_project = "zeevex_threadsafe"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'zeevex_proxy'
  s.add_dependency 'zeevex_delayed'

  s.add_development_dependency 'rspec', '~> 2.9.0'
  s.add_development_dependency 'rake'
end
