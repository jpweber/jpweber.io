+++
title = "Howto Monitor Etcd With Prometheus Operator"
description = ""
author = ""
date = 2018-11-09T22:52:10-05:00
tags = ["prometheus"]
draft = true

+++

[prometheus-operator/monitoring-external-etcd.md at master · coreos/prometheus-operator · GitHub](https://github.com/coreos/prometheus-operator/blob/master/contrib/kube-prometheus/docs/monitoring-external-etcd.md)

Use the etcd.jsonnet file as the jsonnetfile in the compilation phase


get Etcd client cert and key and CA. Put them in the manifests dir. They will be encoded and put in to manifests by the build.sh script

`./build.sh example.jsonnet`

---
# Monitoring External Etcd Cluster with Prometheus Operator
## What/Why
### Requirements
* Jsonnet `brew install jsonnet` or download release from [Releases · google/go-jsonnet · GitHub](https://github.com/google/go-jsonnet/releases)
* jb `go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb`
* cfssl 
  * `go get -u github.com/cloudflare/cfssl/cmd/cfssl`
  * `go get -u github.com/cloudflare/cfssl/cmd/cfssljson`

## How
In the prometheus operator `prometheus-operator/contrib/kube-prometheus` dir run the following
```
$ mkdir my-kube-prometheus; cd my-kube-prometheus
$ jb init  # Creates the initial/empty `jsonnetfile.json`
# Install the kube-prometheus dependency
$ jb install github.com/coreos/prometheus-operator/contrib/kube-prometheus/jsonnet/kube-prometheus  # Creates `vendor/` & `jsonnetfile.lock.json`, and fills in `jsonnetfile.json`
```
### Jsonnet mix-in
`/Users/jamesweber/Development/prometheus-operator/contrib/kube-prometheus/examples/etcd.jsonnet`

### Create Etcd certs
`cfssl gencert -ca etcd/ca.crt -ca-key etcd/ca.key  etcd-client.json | cfssljson -bare etcd-client`

```
mv etcd-client.pem etcd-client.crt
mv etcd-client-key.pem etcd-client.key
```


### build manifests
`./build.sh`