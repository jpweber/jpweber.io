+++
title = "Howto Monitor Etcd With Prometheus Operator"
description = ""
author = ""
date = 2018-11-09T22:52:10-05:00
tags = ["prometheus"]
draft = true
+++

# Monitoring External Etcd Cluster with Prometheus Operator

The recommended way to run etcd for kubernetes is to have your etcd cluster outside of the kubernetes cluster. You might be thinking create a service monitor to monitor an external service like you’ve done before. But, you’ve secured your etcd cluster so you need client certs to talk to it right? Now we need a way to provide certs to the service monitor.  Sure enough we can do all of that by creating certs as kubernetes secrets and adding a `tlsConfig` to our service monitor.

reference previous entry on services and service monitors

## Service

First the service that will describe our etcd cluster must be created. Notice that the selector is `null` here. We are not auto-discovering any endpoints because through selectors, but instead are going to manually define them.

``` yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: etcd
  name: etcd
  namespace: kube-system
spec:
  clusterIP: None
  ports:
  - name: metrics
    port: 2379
    targetPort: 2379
  selector: null
```

## Endpoints

Here were are going to list the endpoints for our etcd servers and then attach them to our service we created in the previous step.  Change the IP addresses to match the IPs of your etcd servers. The way these endpoints are connected to the previously created service is through the `name` property of the metadata. This _must_ match the name of the service you created.

``` yaml
apiVersion: v1
kind: Endpoints
metadata:
  labels:
    k8s-app: etcd
  name: etcd
  namespace: kube-system
subsets:
- addresses:
  - ip: 162.44.15.221
  - ip: 162.44.15.222
  - ip: 162.44.15.223
  ports:
  - name: metrics
    port: 2379
    protocol: TCP
```

## Service Monitor

In order for the prometheus operator to easily discover and start monitoring your etcd cluster, a Service Monitor needs to be created. A Service Monitor is a resource defined by the operator that describes how to  find a specified service to scrape, in this case our etcd service. It also defines things such as how often to scrape, what port to connect to and additionally in this case a configuration for how to establish TLS connections.  
The paths for the CA, client cert and key are the paths will will mount this files to inside the container. We will be generating these files and creating Kubernetes Secrets for them in the next steps.

``` yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: etcd
  name: etcd
  namespace: kube-system
spec:
  endpoints:
  - interval: 30s
    port: metrics
    scheme: https
    tlsConfig:
      caFile: /etc/prometheus/secrets/kube-etcd-client-certs/etcd-client-ca.crt
      certFile: /etc/prometheus/secrets/kube-etcd-client-certs/etcd-client.crt
      keyFile: /etc/prometheus/secrets/kube-etcd-client-certs/etcd-client.key
      serverName: etcd-cluster
  jobLabel: k8s-app
  selector:
    matchLabels:
      k8s-app: etcd
```

## TLS configuration and Kubernetes Secrets

In order to speak to a secured etcd cluster we need client certificates. Using the CA that was used on the etcd cluster we can create a  client certificate and key specifically for prometheus to use.

### Create Etcd Client Certificates

In this example I am using [cfssl](https://github.com/cloudflare/cfssl) to generate my cert and key, but you can use another tool such as OpenSSL if you prefer.

``` shell
cfssl gencert -ca etcd/ca.crt -ca-key etcd/ca.key  etcd-client.json | cfssljson -bare etcd-client
```

The above command will generate two new files named `etcd-client.pem` and `etd-client-key.pem`  I like to rename them for easier use and identification.

``` shell
mv etcd-client.pem etcd-client.crt
mv etcd-client-key.pem etcd-client.key
```

### Create Kubernetes  Secrets

Now that a certificate and key for prometheus has been created we are going to save them, along with the etcd ca as a [kubernetes secret](https://kubernetes.io/docs/concepts/configuration/secret/)This will allow prometheus  to securely connect to etcd.

``` shell
 kubectl -n monitoring create secret kube-etcd-client-certs --from-file=etcd-client-ca.crt=etcd-client.ca.crt --from-file=etcd-client.crt=etcd-client.crt --from-file=etcd-client.key=etcd-client.key
```

In the above snippet it is important that the secrets are created in the same namespace that the Prometheus Operator is running.

### Update the prometheus yaml

We are almost done, this is the last file to modify before we can apply our changes.  I like to use the `kube-prometheus` manifests for deploying the Prometheus Operator and accompanying tools such as alert manager and Grafana. These can be found in `manifests/` or `contrib/kube-prometheus/manifests/` depending on when you clone the Prometheus Operator git repo. Inside this directory is a file called `prometheus-prometheus.yaml` . We need to update this file to include the name of the secrets that we  just created.

![](/images/prom-secrets-diff.png)

The end result should be something like the following

``` yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  labels:
    prometheus: k8s
  name: k8s
  namespace: monitoring
spec:
  alerting:
    alertmanagers:
    - name: alertmanager-main
      namespace: monitoring
      port: web
  baseImage: quay.io/prometheus/prometheus
  nodeSelector:
    beta.kubernetes.io/os: linux
  replicas: 2
  resources:
    requests:
      memory: 400Mi
  ruleSelector:
    matchLabels:
      prometheus: k8s
      role: alert-rules
  secrets:
  - kube-etcd-client-certs
  serviceAccountName: prometheus-k8s
  serviceMonitorNamespaceSelector: {}
  serviceMonitorSelector: {}
  version: v2.4.2
```

## Apply it all

That's it. Now we just need to apply these files to our cluster.  

```shell
Kubectl apply -f etcd-service.yaml
Kubectl apply -f etcd-serviceMon.yaml
Kubectl apply -f prometheus-prometheus.yaml
```

## Conclusion

## TLDR

* repo with all example yaml files
  Github.com/jpweber/monitor-etcd-prometheus-examples
  1. Create etcd `Service` resource
  2. Create `Endpoint` resource for the etcd `Service`
  3. Generate client certificate and key.
  4. Save etcd CA, client cert and key as kubernetes secrets
  5. Update prometheus-prometheus.yaml file
  6. Apply your new files to cluster