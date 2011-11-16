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

require 'net/http'
require 'csv'

host = ARGV[0] || '127.0.0.1'
path = ARGV[1] || '/admin?stats'
@test = ARGV[2] == 'test'

def gmetric(group, name, units, value, slope='both', type='int32')
  cmd = "/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name=#{group}_#{name} --type=#{type} --units=#{units} --value=#{value} --slope=#{slope} --dmax=600"
  #waiting for 3.2
  #cmd = "/usr/bin/gmetric -c /etc/ganglia/gmond.conf --group=#{group} --name=#{name} --type=#{type} --units=#{units} --value=#{value} --slope=#{slope} --dmax=600"
  @test ? puts(cmd) : `#{cmd}`
end

output = {}
body = Net::HTTP.get(host, path+';csv')

#I don't want to depend on rubygems
if RUBY_VERSION >= "1.9.0"
  CSV.parse(body, {:headers => true, :return_headers => false}).each do |row|
    #TODO
  end
else
  parsed = CSV.parse(body)
  parsed.shift #shift headers
  parsed.each do |line|
    next if line[1] != 'BACKEND'
    output[line[0]] = {'stot' => line[7], 'bin' => line[8], 'bout' => line[9]}
  end
end

all_metrics = {'stot' => ['Sessions', 'Sess/s', 'positive'],
               'bin' => ['Bytes_In', 'Bytes/s', 'positive'],
               'bout' => ['Bytes_Out', 'Bytes/s', 'positive']}

output.each do |be, stats|
  all_metrics.each do |name, params|
    #every BE has its own group
    gmetric('haproxy_'+be, params[0], params[1], stats[name], params[2])
  end
end
