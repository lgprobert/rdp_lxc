import os
import sys
import json
import simplejson
from collections import OrderedDict

with open('cluster.config.sample', 'r') as f:
        data=json.load(f, object_pairs_hook=OrderedDict)

nodeDict=OrderedDict()
with open('rdp.cluster') as f:
    for line in f:
        node, role = line.split(':')
        nodeDict.update({node:role})

i=1
nodeList=[]
for host in nodeDict.keys():
    nodeMap=OrderedDict()
    nodeMap['name']="node"+str(i)
    if nodeDict[host].rstrip() == 'dqc':
        nodeMap['role']="DQC"
    nodeMap['hostname']=host
    nodeList.append(nodeMap)
    i+=1

#print json.dumps(nodeList, indent=4)
data['nodeConfig']=nodeList

with open('cluster.config', 'w') as f:
        f.write(simplejson.dumps(data, indent=4, sort_keys=True))

print json.dumps(data, indent=4)
