require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'


RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  SPEC_PLATFORMS = ENV.has_key?('SPEC_PLATFORMS') ? 
        ENV['SPEC_PLATFORMS'].split(/ +/) :
        %w{1.9.3-p448 2.0.0-p247 1.8.7-p374}

  desc "Run on three Rubies"
  task :platforms do
    # current = %x[rbenv version | awk '{print $1}']
    
    fail = false
    SPEC_PLATFORMS.each do |version|
      puts "Switching to #{version}"
      Bundler.with_clean_env do
        system %{bash -c 'eval "$(rbenv init -)" && rbenv use #{version} && rbenv rehash && ruby -v && bundle exec rake spec'}
      end
      if $?.exitstatus != 0
        fail = true
        break
      end
    end

    exit (fail ? 1 : 0)
  end

  desc 'Install gems for all tested rubies'
  task :platform_setup do
     SPEC_PLATFORMS.each do |version|
      puts "Setting up platform #{version}"
      Bundler.with_clean_env do
        system %{bash -c 'eval "$(rbenv init -)" && rbenv use #{version} && rbenv rehash && gem install bundler && bundle install'}
      end
    end   
  end
end


task :repl do
  sh %q{ bundle exec irb -Ilib -r zeevex_threadsafe/synchronized }
end

task :default => 'spec'
