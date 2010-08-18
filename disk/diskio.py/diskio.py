#!/usr/bin/python
###############################################################
# gmetric For Disk IO 
###############################################################
# REQs: pminfo, gmetric
# DATE: 21 December 2004
# (C)2004 DigiTar, All Rights  Reserved
###############################################################

import os, re, time

### Set Sampling Interval (in secs)
interval = 1

### Set PCP Config Parameters
cmdPminfo = "/usr/bin/pminfo -f "
reDiskIO = re.compile(r'"(\w+)"] value (\d+)\n')	# RegEx To Compute Value

### Set Ganglia Config Parameters
gangliaMetricType = "uint32"
gangliaMcastPort = "8649"
### NOTE: To add a new PCP disk metric, add the appropriate entry to each dictionary item of gangliaMetrics
###       Each "vertical" column of the dictionary is a different metric entry group.
gangliaMetrics = { "pcpmetric": ["disk.dev.read", "disk.dev.write", "disk.dev.blkread", "disk.dev.blkwrite"], \
		   "name": ["diskio_readbytes", "diskio_writebytes", "diskio_readblks", "diskio_writeblks"], \
		   "unit": ["Kbytes/s", "Kbytes/s", "Blocks/s", "Blocks/s"], \
	   	   "type": ["uint32", "uint32", "uint32", "uint32"]}
cmdGmetric = "/usr/bin/gmetric"

### Zero Sample Lists
### NOTE: Make sure each sample array has as many (device) sub-arrays as there are pcpmetrics being sampled
### NOTE: Sub-arrays are artificially sized at 4 disk devices...if you have more disk devices than 4, increase this size.
lastSample = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
currSample = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]

### Read PCP Metrics
while(1):
	# Interate Through Each PCP Disk IO Metric Desired
	for x in range(0, len(gangliaMetrics["pcpmetric"])):
		pminfoInput, pminfoOutput = os.popen2(cmdPminfo + gangliaMetrics["pcpmetric"][x], 't')
		deviceLines = pminfoOutput.readlines()
		pminfoInput.close()
		pminfoOutput.close()
		
		# Output Metric Data For Each Device Returned By The PCP Metric
		deviceIndex = 2		# Skip the first two lines in the buffer
		while(deviceIndex < len(deviceLines)):
			result = reDiskIO.search(deviceLines[deviceIndex])
			if(result):
				currSample[x][deviceIndex] = int(result.group(2))
				cmdExec = cmdGmetric + " --name=" + gangliaMetrics["name"][x] + "_" + \
						   result.group(1) + " --value=" + str((currSample[x][deviceIndex] - lastSample[x][deviceIndex])) + \
						   " --type=" + gangliaMetrics["type"][x] + " --units=\"" + gangliaMetrics["unit"][x] + "\"" +  \
						   " --mcast_port=" + gangliaMcastPort
				gmetricResult = os.system(cmdExec)
			lastSample[x][deviceIndex] = currSample[x][deviceIndex]
			deviceIndex = deviceIndex + 1
	time.sleep(interval)