#require 'ruby-debug'

unless ARGV.any? {|a| a =~ /^gems/}

  begin
    require 'cucumber/rake/task'

    require File.join(File.dirname(__FILE__), '../lib/cucumber_slicer')

    namespace :cucumber do
      namespace :slicer do

        # Sets up the Rails environment for Cucumber
        desc "Prepare test database and seed data for cucumber"
        task :prepare => :environment do
          Cucumber::Rake::Slicer.capture do |stdout, stderr|

            # prepare tmp dir
            stdout.puts "Preparing tmp dir"
            Cucumber::Rake::Slicer.clear_tmp_dir
            Cucumber::Rake::Slicer.prepare_tmp_dir

            # prepare connection
            ActiveRecord::Base.configurations['test']['adapter'] = "sqlite3"
            ActiveRecord::Base.configurations['test']['database'] = Cucumber::Rake::Slicer.test_db_path

            # run migration
            stdout.puts "Preparing test db"
            Rake::Task['db:test:prepare'].invoke
            # prepare seed data
            if Rake::Task['db:seed']
              if File.directory?("#{RAILS_ROOT}/db/fixtures")
                ENV["RAILS_ENV"] = "test" # set env for db:seed
                Rake::Task['db:seed'].invoke
                ENV["RAILS_ENV"] = RAILS_ENV # restore env
              end
            end

            stdout.puts "Preparing features db"
            Cucumber::Rake::Slicer.prepare_features_db

          end
        end

        desc "Run all features"
        task :features => :prepare do
          elapsed = Benchmark.realtime do
            Cucumber::Rake::Slicer.capture(false) do |stdout, stderr|
              Cucumber::Rake::Slicer.features.each_with_index do |feature, index|
                feature.sub!("#{RAILS_ROOT}/", "")
                stdout.puts "Running cucumber #{feature}"
                # run each feature in background
                # tips: http://railscasts.com/episodes/127-rake-in-background
                slicer = Cucumber::Rake::Slicer.new(feature)
                slicer.lock_feature
                system "rake cucumber:slicer:run feature=#{feature} >> #{slicer.feature_lock} &"
#                                break if index >= 1 # for debugging
              end

              # watch runners
              @result = Cucumber::Rake::Slicer.watch(1, stdout)
              puts "===================================="
              # falling scenarios
              unless @result[:failing_scenarios].blank?
                puts "\e[31mFailing Scenarios:\e[0m"
                @result[:failing_scenarios].each do |failing_scenario|
                  puts failing_scenario
                end
                puts ""
              end
              puts "#{@result[:total_features]} features (#{@result[:failed_features] > 0 ? "\e[31m#{@result[:failed_features]} failed\e[0m, " : ""}\e[32m#{@result[:passed_features]} passed\e[0m)"
              puts "#{@result[:total_scenarios]} scenario (#{@result[:failed_scenarios] > 0 ? "\e[31m#{@result[:failed_scenarios]} failed\e[0m, " : ""}\e[32m#{@result[:passed_scenarios]} passed\e[0m)"
              puts "#{@result[:total_steps]} steps (#{@result[:failed_steps] > 0 ? "\e[31m#{@result[:failed_steps]} failed\e[0m, " : ""}#{@result[:skipped_steps] > 0 ? "\e[36m#{@result[:skipped_steps]} skipped\e[0m, " : ""}\e[32m#{@result[:passed_steps]} passed\e[0m)"
            end
          end
          
          puts "%1.0fm%4.3fs" % elapsed.divmod(60)
        end

        desc "Run one feature"
        task :run => :environment do
          feature = ENV['feature']
          unless feature.blank?
            Cucumber::Rake::Slicer.capture do |stdout, stderr|
              Cucumber::Rake::Slicer.new(feature).run
            end
          end
        end

#        desc "Call Cucumber::Rake::Slicer class method"
#        task :send do
#          Cucumber::Rake::Slicer.send(ENV['method'])
#        end
      end

      desc "Run all cucumber features in parallel."
      task :slicer  => ['cucumber:slicer:prepare', 'cucumber:slicer:features'] do
        Cucumber::Rake::Slicer.clear_tmp_dir
      end

    end

  rescue LoadError
    desc 'cucumber rake task not available (cucumber not installed)'
    task :cucumber do
      abort 'Cucumber rake task is not available. Be sure to install cucumber as a gem or plugin'
    end
  end

end