Chef::Log.info("Setting up the nginx reverse proxy")

node[:deploy].each do |application, deploy|

    if node[:opsworks][:instance][:layers].first != deploy[:environment_variables][:layer]
        Chef::Log.warn("Skipping the deployment of this nginx because it does not match the app layer")
        next
    end

    Chef::Log.info("Cleanup nginx-proxy docker")

    bash "nginx-cleanup" do
        user "root"
        code <<-EOH
            if docker ps | grep nginx-proxy;
            then
                docker stop nginx-proxy
                sleep 3
                docker rm -f nginx-proxy
            fi
            if docker ps -a | grep nginx-proxy;
            then
                docker rm -f nginx-proxy
            fi
            if docker images | grep adamgins/nginx-proxy;
            then
                docker rmi -f $(docker images | grep -m 1 adamgins/nginx-proxy | awk {'print $3'})
            fi
        EOH
    end

    bash "nginx-proxy-run" do
        user "root"
        code <<-EOH
            docker run -d -p 80:80 -p 443:443 --restart=always --volumes-from #{deploy[:application]} --name nginx-proxy -v /var/run/docker.sock:/tmp/docker.sock adamgins/nginx-proxy
        EOH
    end
end
