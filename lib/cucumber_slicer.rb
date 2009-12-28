module Cucumber
  module Rake
    class Slicer
      # Dir.tmpdir # $Id: tmpdir.rb 21774 2009-01-26 02:11:36Z shyouhei $
      # http://ruby-doc.org/core/classes/Dir.html#M002324
      @tmp_dir = "/tmp/cucumber_slicer" # will be faster to run on a mem dir

      attr_accessor :feature

      class << self
        attr_accessor :tmp_dir

        # analyze log file
        def analyze(log_file, remove_log_file = true)
          log_content = File.read log_file
          result = {}
          result[:log_file] = log_file
          result[:log_content] = log_content
          result[:total_scenarios]   = log_content.scan(/^(\d+) scenario.*/).to_s.to_i
          result[:failed_scenarios] = log_content.scan(/^\d+ scenario \(\e\[31m(\d+) failed.*\)/).to_s.to_i
          steps = log_content.scan(/^(\d+) steps \((?:\e\[31m(\d+) failed\e\[0m, \e\[36m(\d+) skipped\e\[0m, )?\e\[32m(\d+) passed\e\[0m\)/).first || [0, 0, 0, 0]
          result[:total_steps]       = steps[0].to_i
          result[:failed_steps]     = steps[1].to_i
          result[:skipped_steps]  = steps[2].to_i
          result[:passed_steps]   = steps[3].to_i
          result[:failing_scenarios] = log_content.scan(/^\e\[31m.+\e\[0m\n$/).to_s.strip
          File.delete log_file if remove_log_file
          result
        end

        # captrue STDOUT and STDERR
        # TODO: work with debugger
        def capture(inject = true, &block)
          old_stdout = $stdout
          old_stderr = $stderr
          if inject
            $stdout = Capture.new
            $stderr = Capture.new
          end
          begin
            block.call(old_stdout, old_stderr)
          ensure
            $stdout = old_stdout
            $stderr = old_stderr
          end
        end

        def clear_tmp_dir
          #          `rm -rf #{tmp_dir}`
          FileUtils.rm_rf tmp_dir
        end

        # get all features
        def features
          Dir.glob("#{features_dir}/*.feature")
        end
        
        def features_dir
          "#{RAILS_ROOT}/features"
        end

        def log_path(feature)
          "#{tmp_dir}/#{File.basename(feature)}.log"
        end

        def prepare_tmp_dir
          #          `mkdir -p #{tmp_dir}`
          FileUtils.mkdir_p tmp_dir
        end

        def prepare_features_db
          features.each do |feature|
            feature_db = "#{File.basename(feature)}.db"
            copy test_db_path, "#{tmp_dir}/#{feature_db}"
          end
        end

        def test_db_path(feature = "test")
          "#{tmp_dir}/#{feature}.db"
        end

        # wait and analyze logs in tmp dir
        def watch(interval = 1, stdout = $stdout)
          @result = {
            :features => {},
            :total_features => 0,
            :passed_features => 0,
            :failed_features => 0,
          }
          loop do
            sleep interval
            locks = Dir.glob("#{Cucumber::Rake::Slicer.tmp_dir}/*.lock")
            logs = Dir.glob("#{Cucumber::Rake::Slicer.tmp_dir}/*.log")
            break if logs.empty? && locks.empty? # all done?
            logs.each do |log|
              feature = "features/#{File.basename(log).sub(".log", "")}"
              slicer = Slicer.new(feature)
              unless slicer.lock?
                @result[:features][feature] = slicer.analyze
                @result[:total_features] += 1
                if @result[:features][feature][:failed_scenarios] > 0
                  @result[:failed_features] += 1
                else
                  @result[:passed_features] += 1
                end
                # out put result
                stdout.puts "# cucumber #{feature}"
                stdout.puts @result[:features][feature][:log_content]
              end
            end
          end
          # sum counter
          @result[:total_scenarios] =  @result[:features].sum {|i,r| r[:total_scenarios]}
          @result[:failed_scenarios] =  @result[:features].sum {|i,r| r[:failed_scenarios]}
          @result[:passed_scenarios] =  @result[:total_scenarios] - @result[:failed_scenarios]
          @result[:total_steps] = @result[:features].sum {|i,r| r[:total_steps]}
          @result[:failed_steps] = @result[:features].sum {|i,r| r[:failed_steps]}
          @result[:skipped_steps] = @result[:features].sum {|i,r| r[:skipped_steps]}
          @result[:passed_steps] = @result[:features].sum {|i,r| r[:passed_steps]}
          @result[:failing_scenarios] = @result[:features].collect {|i,r| r[:failing_scenarios]}.reject(&:blank?)
          @result
        end

      end

      def analyze
        self.class.analyze(log_path)
      end

      def initialize(feature)
        @feature = feature
      end

      def run
        lock_feature
        task = Cucumber::Rake::Task.new(feature) do |t|
          t.fork = true # You may get faster startup if you set this to false
          t.cucumber_opts = "-q #{feature} --out #{log_path} -f rerun -c CUCUMBER_SLICER=#{feature}"
        end
        begin
          task.runner.run
        rescue Exception => ex
          
        ensure
          unlock_feature
        end
      end

      def feature_lock
        "#{log_path}.lock"
      end

      def log_path
        "#{self.class.log_path(feature)}"
      end

      def lock_feature
        FileUtils.touch feature_lock
      end

      def lock?
        File.exists?(feature_lock)
      end

      def unlock_feature
        FileUtils.rm feature_lock
      end

    end

    class Capture
      def initialize(*args, &block)
      end
      # for STDOUT
      def write(txt)
      end

      # for STDERR
      def puts(value)

      end
    end
    
  end
end
