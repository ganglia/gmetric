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

require 'socket'

host = ARGV[0] || '127.0.0.1'
port = ARGV[1] || 11211
@test = ARGV[2] == 'test'

def gmetric(group, name, units, value, slope='both', type='int32')
  cmd = "/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name=#{group}_#{name} --type=#{type} --units=#{units} --value=#{value} --slope=#{slope} --dmax=600"
  #ganglia 3.2
  #cmd = "/usr/bin/gmetric -c /etc/ganglia/gmond.conf --group=#{group} --name=redis_#{name} --type=#{type} --units=#{units} --value=#{value} --slope=#{slope} --dmax=600"
  @test ? puts(cmd) : `#{cmd}`
end

output = {}
socket = TCPSocket.open(host, port)
socket.write("stats\n")
socket.each do |line|
  parts = line.split()
  break if parts[0] == 'END'
  next unless parts[0] == 'STAT'
  output[parts[1]] = parts[2]
end

all_metrics = {}

all_metrics["curr_connections"] = ["curr_connections", "Connections", 'both']
all_metrics["bytes_read"] = ["bytes_read", "bytes read", 'positive']
all_metrics["bytes_written"] = ["bytes_written", "bytes written", 'positive']
all_metrics["bytes"] = ["bytes", "Total bytes", 'both']
all_metrics["limit_maxbytes"] = ["limit_maxbytes", "Max bytes", 'both']
all_metrics["evictions"] = ["evictions", "Evictions", 'positive']

%w(get set flush).each do |cmd|
  all_metrics["cmd_#{cmd}"] = ["cmd_#{cmd}", "#{cmd} commands", 'positive']
end
%w(get delete incr decr cas).each do |cmd|
  all_metrics["#{cmd}_hits"] = ["#{cmd}_hits", "#{cmd} hits", 'positive']
  all_metrics["#{cmd}_misses"] = ["#{cmd}_misses", "#{cmd} misses", 'positive']
end

all_metrics.each do |name, params|
  gmetric('memcached', params[0], params[1], output[name], params[2])
end
