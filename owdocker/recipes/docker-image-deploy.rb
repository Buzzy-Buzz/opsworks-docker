include_recipe 'deploy'
include_recipe 'docker'

Chef::Log.debug("Entering docker-image-deploy")

node[:deploy].each do |application, deploy|

  if node[:opsworks][:instance][:layers].first != deploy[:environment_variables][:layer]
    Chef::Log.debug("Skipping deploy::docker application #{application} as it is not deployed to this layer")
    next
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  Chef::Log.debug('Docker cleanup')
  bash "docker-cleanup" do
    user "root"
    code <<-EOH
      if docker ps | grep #{deploy[:application]};
      then
        docker stop #{deploy[:application]}
        sleep 3
        docker rm -f #{deploy[:application]}
      fi
      docker rmi -f #{deploy[:environment_variables][:registry_image]}:#{deploy[:environment_variables][:registry_tag]}
    EOH
  end

  Chef::Log.debug('REGISTRY: Login as #{deploy[:environment_variables][:registry_username]} to #{deploy[:environment_variables][:registry_url]')
  docker_registry '#{deploy[:environment_variables][:registry_url]}' do
    username '#{deploy[:environment_variables][:registry_username]}'
    password '#{deploy[:environment_variables][:registry_password]}'
  end

  # Pull tagged image
  Chef::Log.debug('IMAGE: Pulling #{deploy[:environment_variables][:registry_image]}:#{deploy[:environment_variables][:registry_tag]}')
  docker_image '#{deploy[:environment_variables][:registry_image]}' do
    tag '#{deploy[:environment_variables][:registry_tag]}'
  end

  dockerenvs = " "
  deploy[:environment_variables].each do |key, value|
    dockerenvs=dockerenvs+" -e "+key+"="+value
  end
  Chef::Log.debug('ENVs: #{dockerenvs}')

  Chef::Log.debug('docker-run start')
  bash "docker-run" do
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
      docker run #{dockerenvs} -p #{node[:opsworks][:instance][:private_ip]}:#{deploy[:environment_variables][:service_port]}:#{deploy[:environment_variables][:container_port]} --name #{deploy[:application]} -d grep #{deploy[:environment_variables][:registry_image]}:#{deploy[:environment_variables][:registry_tag]}
    EOH
  end
  Chef::Log.debug('docker-run stop')
end
Chef::Log.debug("Exiting docker-image-deploy")
