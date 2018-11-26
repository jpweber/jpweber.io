+++
title = "Prometheus Operator Service Monitor Without Exposing Service"
description = ""
author = ""
date = 2018-11-09T22:54:41-05:00
tags = ["prometheus"]
draft = true

+++

you have nginx ingress controller, its creating a load balancer for ports 80 and 443, how do you create a service that expose 10254 for the nginx ingress controller without exposing that port on the load balancer?

prometheus operator uses service monitors to decide what to scrape. service monitors needs services to find endpoints. We will make a headless service for the nginx monitoring port and point the prometheus service monitor to that.