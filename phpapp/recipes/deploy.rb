node[:deploy].each do |application, deploy|
  
  # use opsworks ssh key management and load the key into the ec2 instance
  prepare_git_checkouts(
    :user => "root",
    :group => "root",
    :home => "/root/",
    :ssh_key => deploy[:scm][:ssh_key]
  ) if deploy[:scm][:scm_type].to_s == 'git'

  # clone the repo
  execute "cd /var && git clone #{deploy[:scm][:repository]} #{deploy[:application]}" do
    ignore_failure true
  end

  # set any php.ini settings needed
  template "/etc/php.d/#{deploy[:application]}.ini" do
    source "php.conf.erb"
    owner "root"
    group "root"
    mode 0644
  end

  # use opsworks ssh key management and load the key into the ec2 instance. 
  # it's helpful to have the deploy key loaded into the root user

  # copy ssh key to root user
  execute "touch /root/.ssh/id_deploy" do
    ignore_failure true
  end
  
  ssh_key = deploy[:scm][:ssh_key]
  
  execute "copy ssh_key" do
    command "echo '#{ssh_key}' > /root/.ssh/id_deploy"
  end
  
  execute "chmod 0600 /root/.ssh/id_deploy" do
    ignore_failure true
  end

  # make sure the ssh key is loaded
  execute "eval `ssh-agent -s`"
  execute "ssh-agent bash -c 'ssh-add /root/.ssh/id_deploy'"

  # set apache2 hosts
  web_app deploy[:application] do
    server_name "#{deploy[:domains].first}"
    docroot "/var/#{deploy[:application]}/#{deploy[:mounted_at]}"
    template "webapp.conf.erb" 
    log_dir node['apache']['log_dir'] 
  end

  # use simple git pull to deploy code changes
  execute "cd /var/#{deploy[:application]} && git clean -df && git reset --hard && git pull"
  
end