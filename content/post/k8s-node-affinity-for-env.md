---
title: "K8s Node Affinity for Env"
date: 2017-09-28T17:14:46-04:00
draft: true
---

One nice use of name spaces is to split up development environments such as dev, qa, staging, production etc. However, you may still find yourself wanting more separation that just the name spaces. This can be particularly common if you are transitioning from a model where you have multiple subnets for your different development environments and you don't want to re-IP everything and change external firewall rules you may have that are already written for those subnet ranges. 

This is where [Node Affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#node-affinity-beta-feature) comes in. From the docs 
> it allows you to constrain which nodes your pod is eligible to schedule on, based on labels on the node.

Conceptually it works like this. You have a node that has a particular label. In your pod manifest you have a rule that states "only schedule me on nodes that match a particular label"

A way that I have used this in practice is to keep development environments separated by placing pods in a _dev_ name space only on nodes in the _dev_ subnet. These nodes have a label `environment` with a value of `dev`. That way, the only pods on what I consider dev machines are only development pods. You may not have a different subnet requirement, but just want to keep your workload segmented to specific machines. For example, maybe you have a few larger instances that you want to reserve for only a select set of large pods. Or machines with GPUs and you only want workloads that can use them on those boxes. But I'm going to stick with dividing up development environments for the examples. 

The first thing you'll need is labels on your nodes. You'll want to add the following to your kubelet options. `--node-labels environment=dev`. Or a quicker way to try it out is to assign the label with the kubectl command with the following sytnax:
`kubectl label nodes <node-name> <label-key>=<label-value>` 
For example:
`kubectl label nodes ip-172.168.32.21.ec2.local environment=dev`
However I do not recommend relying on someone manually running kubectl to set node labels everytime you launch a new node. 

Now that your nodes have an environment label you need to tell your pods what nodes are OK to be scheduled on. This very simple example will schedule this pod on any node with the label `environment` and a value of `dev`
```apiVersion: v1
kind: Pod
metadata:
 name: mypod
spec:
 containers:
   - name: myshell
     image: "ubuntu:14.04"
     command:
       - /bin/sleep
       - "300"
 nodeSelector:
   environment: dev
```

The important part here is the two lines at the end. 
``` 
nodeSelector:  
   environment: dev
```

Thats all it takes. There are operational concerns with using this technique, such as how are you going to change that envrionment value in your manifests as you move your applications through environments. Making sure you have enough nodes with that label to satisfy your workloads etc. 