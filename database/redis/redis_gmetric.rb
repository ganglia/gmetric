#!/usr/bin/ruby

#
# Author:: Gilles Devaux (<gilles@formspring.me>)
# Copyright:: Copyright (c) 2011 Formspring.me
# License:: Apache License, Version 2.0
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

host = ARGV[0] || '127.0.0.1'
port = ARGV[1] || 6379
@test = ARGV[2] == 'test'

def gmetric(group, name, units, value, slope='both')
  cmd = "/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name=#{group}_#{name} --type=#{type} --units=#{units} --value=#{value} --slope=#{slope} --dmax=600"
  #ganglia 3.2
  #cmd = "/usr/bin/gmetric -c /etc/ganglia/gmond.conf --group=#{group} --name=redis_#{name} --type=#{type} --units=#{units} --value=#{value} --slope=#{slope} --dmax=600"
  @test ? puts(cmd) : `#{cmd}`
end

output = {}
IO.popen("redis-cli -h #{host} -p #{port} info").each do |line|
  next if line.empty?
  s = line.split(':')
  output[s[0]] = s[1].chomp
end
exit if output.empty?

all_metrics = {'used_memory' => ['used_memory', 'bytes', 'both'],
               'connected_clients' => ['clients', 'clients', 'both'],
               'total_commands_processed' => ['commands', 'Cmds/s', 'positive'],
               'total_connections_received' => ['connections', 'Conn/s', 'positive']}

all_metrics.each do |name, params|
  gmetric('redis', params[0], params[1], output[name], params[2])
end
