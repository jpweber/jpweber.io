---
title: "K8s 1.7 Master Changes"
date: 2017-09-12T17:14:18-04:00
draft: false
---

In k8s 1.7 the deprecated kubelet flag of `register-schedulable` officially got removed. 
Which means in order to keep pods from being scheduled on your controllers you now need to use `register with taints`

Not a big deal except we did get caught by a simple gotcha. Many of the daemonsets no long were scheduled to the controllers when they should have been. One big one being weave net. In order to fix this the following had to be added to the daemonsets that we expect to run on the controllers. 

```
    tolerations:
      - effect: NoSchedule
        operator: Exists
```

