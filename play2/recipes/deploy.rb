#
# Cookbook Name:: play2
# Recipe:: deploy
#

node[:deploy].each do |application, deploy|
  app_dir    = ::File.join(deploy[:deploy_to], "current", deploy[:scm][:app_dir] || '.')
  shared_dir = ::File.join(deploy[:deploy_to], "shared")

  # Stop the application
  execute "stop #{application}" do
    user "root"
    command "sudo service #{application} stop"
    only_if do
      ::File.exists?("/etc/init.d/#{application}")
    end
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  # pull the application code
  opsworks_deploy do
    deploy_data deploy
    app application
  end

  # Create the application configuration file
  template ::File.join(app_dir, "conf/application.conf") do
    source "app_conf.erb"
    owner deploy[:user]
    group deploy[:group]
    mode  "0644"
    variables({
      :flat_conf => play_flat_config(node[:play2][:conf])
    })
    only_if do
      node[:play2][:conf] != nil
    end
  end

  # Create the logging configuration file
  template ::File.join(app_dir, "conf/logger.xml") do
    source "app_logging.erb"
    owner deploy[:user]
    group deploy[:group]
    mode  "0644"
  end

  execute "package #{application}" do
    cwd app_dir
    user "root"
    command "play clean stage"
  end

  # Create the service for the application
  template "/etc/init.d/#{application}" do
    source "app_service.erb"
    owner "root"
    group "root"
    mode  "0755"
    variables({
      :name => application,
      :path => app_dir,
      :options => play_options(),
      :command => "target/start"
    })
  end

  service application do
    supports :status => true, :start => true, :stop => true, :restart => true
    action :enable
  end

  # Start the application
  execute "start #{application}" do
    user "root"
    command "sudo service #{application} start"
  end
end