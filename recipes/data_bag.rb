#
# Cookbook Name:: user
# Recipe:: data_bag
#
# Copyright 2011, Fletcher Nichol
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

bag = node['user']['data_bag_name']

# Fetch the user array from the node's attribute hash. If a subhash is
# desired (ex. node['base']['user_accounts']), then set:
#
#     node['user']['user_array_node_attr'] = "base/user_accounts"
user_array = node
node['user']['user_array_node_attr'].split('/').each do |hash_key|
  user_array = user_array.send(:[], hash_key)
end

# only manage the subset of users defined
Array(user_array).each do |i|
  u = data_bag_item(bag, i.gsub(/[.]/, '-'))
  username = u['username'] || u['id']

  user_permitted = false

  if node['user']['enable_access_controls'] &&
     !node['user']['allowed_groups'].empty? &&
     u['action'] != 'remove' &&
     (u['access_controlled'].nil? || u['access_controlled'] == true)
    u['groups'].each do |g|
      user_permitted = node['user']['allowed_groups'].include?(g)
      break if user_permitted
    end
  else
    user_permitted = true
  end

  user_action = if user_permitted
                  Array(u['action']).map { |a| a.to_sym }[0] if u['action']
                else
                  :remove
                end

  user_account username do
    %w{comment uid gid home shell password system_user manage_home create_group
       ssh_keys ssh_keygen non_unique}.each do |attr|
      send(attr, u[attr]) if u[attr]
    end
    action user_action
  end

  if !u['groups'].nil? && user_action != :remove
    u['groups'].each do |groupname|
      group groupname do
        members username
        append true
      end
    end
  end
end
