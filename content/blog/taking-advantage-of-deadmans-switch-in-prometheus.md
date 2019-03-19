+++
title = "Taking Advantage of Deadmans Switch in Prometheus"
description = "Who watches the watchers"
author = "Jim Weber"
date = 2019-03-19T15:50:15-04:00
tags = ["kubernetes", "prometheus"]
draft = true

+++

# 

How do you know your monitoring system is working? leverage a Deadman switch alert with an external service that listens for Deadman Switch alerts and the absence of those alerts.

## Purpose and background
When creating systems, monitoring to know the health of your systems is important. Be it a car with it's basic engine light, a server that checks that a process is running, or a complicated distributed system that ensures things are happening within acceptable latencies. Some form of monitoring is how you know your system is working as expected. These can range from seemingly simple, to very complex. The thing that they all have in common is that we rely on them to ensure our systems are working as expected. But then who or what monitors the monitoring system? How do you know the system you rely on to know the health of a system is - healthy?

Working with Kubernetes and specifically prometheus, this question comes up from time to time. 

> “How do I know my monitoring system is working”. 

This is a question anyone to implements a monitoring system should ask. Fortunately there is a basic concept that can solve this problem. A [Dead man’s switch](https://en.wikipedia.org/wiki/Dead_man%27s_switch)

A dead man’s switch, in the physical world, is fairly easy to understand. There is some system, that requires human interaction to function. If human interaction does not occur, the system ceases to function. For example, one that many people are probably familiar with is on a lawn mower. On many gas or electric lawn mowers there is a lever or bar you must hold down for the engine to run. If you let go of the handle, including the bar you are holding down, the engine stops running. This is to prevent a runway lawn mower causing damage or harm. Another example, which first introduced me to the concept is on trains. A train conductor on modern trains may be standing or sitting for a significant amount of time without needing to interact with the train. But, because we don’t want people literally sleeping on the job, trains will have a “dead man’s switch” to ensure the conductor is awake and alert. This can take many forms but a common one is simple a light and a button.  On a control panel a light turns on, the conductor must push the button, and train keeps on going. If the conductor does _not_ push the button the train will stop, assuming the conductor is incapacitated and cannot operate the train as needed.

In software this can work much in the same way, but in the case of systems monitoring we don’t need to bring a human in to the equation. Imagine for example, if you had an alerting system that sent out alerts at a regular interval, a heartbeat if you will. You also had some other system, outside of your primary system, that was listening for those alerts. Now imagine your outside system stopped receiving those alerts or heartbeats. It could then tell someone that it stopped receiving messages. This is the essence of the dead man’s switch with prometheus, and how one can monitor your monitoring system.

## Prometheus DeadMan Switch Alert Rule
Within prometheus it is trivial to create an expression that we can build a DeadMan switch from. 
```
expr: vector(1)
```

That expression will always return true.  Here is an alert that leverages the previous expression to create a dead man switch alert.

```
     - alert: DeadMansSwitch
       annotations:
         description: This is a DeadMansSwitch meant to ensure that the entire Alerting
           pipeline is functional.
         summary: Alerting DeadMansSwitch
       expr: vector(1)
       labels:
         severity: none
```

This will send an alert off to your alertmanager with that description, summary and severity. Change as you see fit.
I first became aware of this years ago, I don’t recall where I first learned this trick, but honestly it was probably from someone at CoreOS, as the code above is from the Prometheus Operator which has its roots at CoreOS.

Ok, great. You have something that will send alerts all the time but now what?  There are few good options, but usually the answer is “oh just make something that listens for those and then sends you alerts” very hand wavy, and easy to say, but leaves out a lot of details. I created a usable [implementation](https://github.com/jpweber/cole) of said hand waviness to show how this works. Use whatever you like, and what works best for you. The rest of what I cover here _does not_ assume you are using the tool I wrote because the concepts should apply universally.

## Alert Manager Config
You’ve got your Dead man switch alert. Next we need to setup alertmanager to know how to deal with these dead man switch alerts.

The below example has global config and other routes cut out, but I left the section headings in so you can see how this fits in the structure of an alertmanager config file.

``` yaml
global:
 ...
route:
 ...
    routes:
    - match:
        alertname: DeadMansSwitch
        receiver: 'cole'
        group_wait: 0s
        group_interval: 1m
        repeat_interval: 50s
receivers:
- name: 'cole'
webhook_configs:
- url: 'http://192.168.2.66:8080/ping/bg8obqel0s1fdr02gtvg'
    send_resolved: false
```



The important parts we need to add are the, match rule under routes, a reciever, and the webhook config for that reciever.

### Match rules

This defintes how we are going to identify certain alerts, and once we find a match where do we send it. 

* `alertname` is the name of the alert that will be sent with the alert payload
* `receiver`: which receiver to send this alert to
* For `group_wait`, `group_interval` and `repeat_interval` you don’t want to use the default values here because this alert is serving a different purpose. We don’t want to wait for them to be sent or hold back on repeats since we want it to go off at a consistent rate.
* `group_wait`: How long to initially wait to send a notification for a group
  of alerts. Allows to wait for an inhibiting alert to arrive or collect more initial alerts for the same group.
* `group_interval`: How long to wait before sending a notification about new alerts that are added to a group of alerts for which an initial notification has already been sent
* `repeat_interval`: How long to wait before sending a notification again if it has already been sent successfully for an alert.

### Receiver configuration

A receiver defines what to do with an alert that has been routed to it. In our case we are going to be sending the alert payload to a remote webhook. 

* **name** a name for the receiver. This is the name that is referenced in the matching rules.
* **webhook_configs** - this the notification integration that will be used to send out dead man switch alerts to an outside system. This has a a few parameters we are setting:
  * **url** the url to the remote endpoint to send alert messages to
  * **send_resolved**: boolean true or false, do you want to sent a resolved message or not. For the case of the dead man switch it will never resolve so we leave this set to false.



With that, your prometheus instance should be sending regular interval alerts to your alert manager. The alert manager is now configured to capture these alerts and route them to your external service, which will  then signal if it stops recieving these alerts. See the below diagram for how this should be flowing

![deadmananimated](/images/deadmananimated.gif)



Monitoring systems are important to know this are working as you expect. But trust in your monitoring system is equally if not more important. Monitoring your monitoring system is a step in making that trust stronger. I'm sure some of you are thinking, but how do you monitor, your monitoring system monitor. Well, as they say its turtles all the way down. One could keep building this forever but at some point it needs end with something that is considered acceptable. This isn't a silver bullet, but it is something that will solve for _most_ cases. 

There will be a part two to this post where I go in to `Cole`  and how one can use it  monitor the health of their alerting  system. 