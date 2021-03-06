#
# Cookbook Name:: chef-kibana_auth
# Recipe:: default
#
# Copyright (C) 2014 Twiket LTD
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'runit'
include_recipe 'kibana::default'

node['kibana']['auth']['gems'].each {|g| gem_package g}

node.default['kibana']['auth']['install_dir'] = "#{node['kibana']['install_dir']}/kibana_auth"
auth_dir = "#{node['kibana']['auth']['install_dir']}/#{node.default['kibana']['auth']['branch']}"
kibana_user = node[node['kibana']['webserver']]['user']

cookbook_file node['kibana']['auth']['file_path'] do
  source    node['kibana']['auth']['file_name']
  mode      0640
  owner     kibana_user
  group     kibana_user
  cookbook  node['kibana']['auth']['file_cookbook']
end

directory ::File.dirname(auth_dir) do
  recursive true
  owner kibana_user
  mode 0755
end

git auth_dir do
  repository node['kibana']['auth']['repo']
  reference  node['kibana']['auth']['branch']
  case  node['kibana']['auth']['git_action'].to_s
    when "checkout"
      action :checkout
    when "sync"
      action :sync
  end
  user kibana_user
end
link "#{node['kibana']['auth']['install_dir']}/current" do
  to auth_dir
end

directory "#{node['kibana']['auth']['install_dir']}/current/kibana" do
  recursive true
  action    :delete
end
link "#{node['kibana']['auth']['install_dir']}/current/kibana" do
  to node['kibana']['web_dir']
end

template "#{node['kibana']['auth']['install_dir']}/current/config.rb" do
  owner kibana_user
  mode  0640
  source 'config.rb.erb'
  notifies :restart, "service[kibana]", :delayed
end

es_url =  "#{node['kibana']['es_scheme']}" <<
  "#{node['kibana']['es_server']}:#{node['kibana']['es_port']}"

node.default['kibana']['auth']['config']['elasticsearch'] = es_url

template '/etc/init/kibana.conf' do
  owner   'root'
  group   'root'
  mode    00644
  source  'kibana-upstart.conf.erb'
  variables(
    :user       => kibana_user,
    :webserver  => node['kibana']['auth']['webserver'],
    :bind       => node['kibana']['auth']['bind'],
    :port       => node['kibana']['auth']['port'],
    :rundir     => "#{node['kibana']['auth']['install_dir']}/current"
  )
end

# !Runit can not be used due to application forking
# Use upstart
service "kibana" do
  action   [:enable, :start]
  provider Chef::Provider::Service::Upstart
end
