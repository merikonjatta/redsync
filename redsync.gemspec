Gem::Specification.new do |s|
  s.name = 'redsync'
  s.version = '0.1.2'
  s.summary = "Sync Redmine's wiki pages to your local filesystem."
  s.description = "Sync Redmine's wiki pages to your local filesystem. Edit as you like, then upsync."
  s.authors = ["merikonjatta"]
  s.email = "merikonjatta@gmail.com"
  s.homepage = "http://github.com/merikonjatta/redsync"

  s.files = Dir["**/*.rb", "**/*.textile", "config.yml.dist"]
  s.require_paths = ["lib"]
  s.executables = ["redsync"]
  s.test_files = Dir["test/**/*.rb"]

  s.add_runtime_dependency 'mechanize', '~>2.0'
  s.add_runtime_dependency 'activesupport'
  s.add_runtime_dependency 'ir_b'
end
