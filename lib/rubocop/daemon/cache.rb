# frozen_string_literal: true

require 'pathname'

module RuboCop
  module Daemon
    class Cache
      class << self
        # Searches for Gemfile or gems.rb in the current dir or any parent dirs
        def project_dir
          current_dir = Dir.pwd
          while current_dir != '/'
            return current_dir if %w[Gemfile gems.rb].any? do |gemfile|
              File.exist?(File.join(current_dir, gemfile))
            end

            current_dir = File.expand_path('..', current_dir)
          end
          # If we can't find a Gemfile, just use the current directory
          Dir.pwd
        end

        def project_dir_cache_key
          @project_dir_cache_key ||= project_dir[1..-1].tr('/', '+')
        end

        def dir
          cache_path = File.expand_path('~/.cache/rubocop-daemon')
          Pathname.new(File.join(cache_path, project_dir_cache_key)).tap do |d|
            d.mkpath unless d.exist?
          end
        end

        def port_path
          dir.join('port')
        end

        def token_path
          dir.join('token')
        end

        def pid_path
          dir.join('pid')
        end

        def lock_path
          dir.join('lock')
        end

        def status_path
          dir.join('status')
        end

        def pid_running?
          Process.kill(0, pid_path.read.to_i) == 1
        rescue Errno::ESRCH
          false
        end

        def acquire_lock
          lock_file = File.open(lock_path, File::CREAT)
          # flock returns 0 if successful, and false if not.
          flock_result = lock_file.flock(File::LOCK_EX | File::LOCK_NB)
          yield flock_result != false
        ensure
          lock_file.flock(File::LOCK_UN)
          lock_file.close
        end

        def write_port_and_token_files(port:, token:)
          port_path.write(port)
          token_path.write(token)
        end

        def write_pid_file
          pid_path.write(Process.pid)
          yield
        ensure
          dir.rmtree
        end

        def write_status_file(status)
          status_path.write(status)
        end
      end
    end
  end
end
