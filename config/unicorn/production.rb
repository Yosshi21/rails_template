# -*- coding: utf-8 -*-
worker_processes Integer(ENV["WEB_CONCURRENCY"] || 3)
timeout 180
preload_app true # 更新時ダウンタイム無し

app_path = '/app/katana'
# app_path = File.expand_path('../../', __FILE__)
app_shared_path = "#{app_path}/shared"
working_directory "#{app_path}/current"

# listen "/var/run/sockets/unicorn.sock"
listen "#{app_shared_path}/tmp/sockets/unicorn.sock"

stdout_path "#{app_shared_path}/log/unicorn.stdout.log"
stderr_path "#{app_shared_path}/log/unicorn.stderr.log"

# pid "/var/run/pids/unicorn.pid"
pid "#{app_shared_path}/tmp/pids/unicorn.pid"

# ログの出力
stderr_path File.expand_path('log/unicorn_error.log', ENV['RAILS_ROOT'])
stdout_path File.expand_path('log/unicorn.log', ENV['RAILS_ROOT'])

before_fork do |server, worker|
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!

  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("WINCH", File.read(old_pid).to_i)
      Thread.new {
        sleep 30
        Process.kill("KILL", File.read(old_pid).to_i)
      }
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did job for us
    end
  end
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
