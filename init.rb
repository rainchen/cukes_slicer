# Include hook code here
unless ARGV.grep(/^CUCUMBER_SLICER=(.+)/).blank?
  if RAILS_ENV == 'test'
    require 'cucumber_slicer'
    feature = $1
    # prepare db connection
    ActiveRecord::Base.configurations['test']['adapter'] = "sqlite3"
    ActiveRecord::Base.configurations['test']['database'] = Cucumber::Rake::Slicer.test_db_path(File.basename(feature))
  end
end
