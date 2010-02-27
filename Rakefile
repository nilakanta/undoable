require 'rubygems'
require 'rake/rdoctask'
require 'rake'

if File.exists?(File.dirname(__FILE__) + '/../../../config/environment.rb')
  puts 'Using vendored Rspec'
  $LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + "/../rspec/lib")
else
  puts 'Using Rspec gem'
  gem 'rspec'
end

require 'spec'
require 'spec/rake/spectask'

puts "Building on Ruby #{RUBY_VERSION}, #{RUBY_RELEASE_DATE}, #{RUBY_PLATFORM}"

desc 'Default: run spec tests.'
task :default => :spec

desc "Run all specs"
Spec::Rake::SpecTask.new(:spec) do |task|
  task.spec_files = FileList['spec/**/*_spec.rb']
  task.spec_opts = ['--options', 'spec/spec.opts']
end

desc 'Generate documentation'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = 'Documentation'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'rcov'
  require 'rcov/rcovtask'
  desc "Run all specs in spec directory with RCov"
  Spec::Rake::SpecTask.new(:rcov) do |t|
    t.spec_opts = ['--options', "spec/spec.opts"]
    t.spec_files = FileList["spec/**/*_spec.rb"]
    t.rcov = true
    t.rcov_opts = lambda do
      IO.readlines("spec/rcov.opts").map {|l| l.chomp.split " "}.flatten
    end
    # t.verbose = true
  end
rescue LoadError
  puts "Rcov not available. Install using `sudo gem ins rcov`."
end
