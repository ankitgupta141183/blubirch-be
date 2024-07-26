
# Place in /config/puma/production.rb

rails_env = "production"
environment rails_env

app_dir = "/home/deploy/apps/beam_saas"

bind  "unix://#{app_dir}/shared/sockets/puma.sock"
pidfile "#{app_dir}/shared/pids/puma.pid"
state_path "#{app_dir}/shared/states/puma.state"
directory "#{app_dir}/"

stdout_redirect "#{app_dir}/log/puma.stdout.log", "#{app_dir}/log/puma.stderr.log", true

workers 2
threads 1,2

daemonize true

activate_control_app "unix://#{app_dir}/shared/sockets/pumactl.sock"

prune_bundler