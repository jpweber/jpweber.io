+++
title = "A Look at How to Use TokenRequest Api"
description = "Exploring TokenRequest API, TokenReview API and Service account volume projection"
author = "Jim Weber"
date = 2019-04-03T15:28:27-04:00
tags = ["kubernetes"]
draft = false
asciinema = true

+++

The TokenRequest API enables the creation of tokens that aren’t persisted in the Secrets API, that are targeted for specific audiences (such as external secret stores), have configurable expiries, and are bindable to specific pods. These tokens are bound to _specific_ containers. Because of this, they can be used as a means of container identity. The current service account tokens are shared among all replicas of a deployment and thusly, are not a good means of unique identity.

This feature was introduced in kubernetes 1.10 as an alpha feature and graduated to beta status in 1.12, which is the current status in kubernetes 1.14.

I am going to look at how to use the TokenRequest API coupled along with the TokenReview API, [Service Account Volume Projections](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection) and how you can test these features with cURL.  Finally, I'll demonstrate how this would all work together with two example services. One that will get a bound service account token and one that will validate this token.

## How to enable these features

In order to use the TokenRequest API and service account token volume projection, a few flags need to be added to your `kube-apiserver` manifest, seen below. If you are adding this to an existing cluster, in most installations this file will be found at `/etc/kubernetes/manifests/kube-apiserver.yaml`

``` yaml
- --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
- --service-account-key-file=/etc/kubernetes/pki/sa.pub
- --service-account-issuer=api
- --service-account-api-audiences=api,vault,factors
```

If you are using kubeadm these would be added as apiServer extraArgs in your `kubeadm.conf` file. See example below

```yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
apiServer:
  extraArgs:
    service-account-signing-key-file: /etc/kubernetes/pki/sa.key
    service-account-key-file: /etc/kubernetes/pki/sa.pub
    service-account-issuer: api
    service-account-api-audiences: api,vault,factors
```

Before adding those to your manifest file lets go over what they are.

* **service-account-signing-key-file:**
  Path to the file that contains the current private key of the service account token issuer. The issuer will sign issued ID tokens with this private key.

* **service-account-key-file:**
  File containing PEM-encoded x509 RSA or ECDSA private or public keys, used to verify ServiceAccount tokens. The specified file can contain multiple keys, and the flag can be specified multiple times with different files. If unspecified, ``--tls-private-key-file` is used. Must be specified when ``--service-account-signing-key` is provided

* **service-account-issuer:**
  Identifier of the service account token issuer. The issuer will assert this identifier in the `iss` claim of issued tokens. This value is a string or URI.

* **service-account-api-audiences:**
  Identifiers of the API. The service account token authenticator will validate that tokens used against the API are bound to at least one of these audiences. If the `--service-account-issuer` flag is configured and this flag is not, this field defaults to a single element list containing the issuer URL.

## Testing the API Endpoints with cURL

### Get a user bearer token

To successfully make HTTP requests to the Kubernetes API a bearer token must be included as an authorization header. Below is an example command one could run to get the bearer token for a user named `admin-user` in the namespace of `kube-system`. This same command could apply to any other user or namespace. 

```shell
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```

### TokenRequest Call

Curl template:

```bash
curl -X "POST" "https://{kubernetes API IP}:{kubernetes API Port}/api/v1/namespaces/{namespace}/serviceaccounts/{name}/token" \
     -H 'Authorization: Bearer {your bearer token}' \
     -H 'Content-Type: application/json; charset=utf-8' \
     -d $'{}'
```

Example populated from my test cluster:

``` shell
curl -k -X "POST" "https://192.168.2.173:6443/api/v1/namespaces/token-demo/serviceaccounts/token-client-test/token" \
     -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLWNxbng3Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiI2NzUwMGUzNC00NzM2LTExZTktODcxNi0wMDUwNTZiZjRiNDAiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06YWRtaW4tdXNlciJ9.kXpaaOkb8WnUBEiVUCvRbHexGhVxj3WY6m_H07limQ2WUOyNHGT2hf3RNsjnz-6ie...<snip>...' \
     -H 'Content-Type: application/json; charset=utf-8' \
     -d $'{}'
```

### TokenRequest Response

```json
{
  "kind": "TokenRequest",
  "apiVersion": "authentication.k8s.io/v1",
  "metadata": {
    "selfLink": "/api/v1/namespaces/token-demo/serviceaccounts/token-client-test/token",
    "creationTimestamp": null
  },
  "spec": {
    "audiences": [
      "api",
      "vault",
      "factors"
    ],
    "expirationSeconds": 3600,
    "boundObjectRef": null
  },
  "status": {
    "token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJhdWQiOlsiYXBpIiwidmF1bHQiLCJmYWN0b3JzIl0sImV4cCI6MTU1NDIyODI0OCwiaWF0IjoxNTU0MjI0NjQ4LCJpc3MiOiJhcGkiLCJrdWJlcm5ldGVzLmlvIjp7Im5hbWVzcGFjZSI6InRva2VuLWRlbW8iLCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoidG9rZW4tY2xpZW50LXRlc3QiLCJ1aWQiOiIwNTQ3NTc5Yy01MGJmLTExZTktYjY4NS0wMDUwNTZiZjRiNDAifX0sIm5iZiI6MTU1NDIyNDY0OCwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OnRva2VuLWRlbW86dG9rZW4tY2xpZW50LXRlc3QifQ.VHBWYHBMEAQnQAzbdyr4KHjYCU5wtq32B3dI8Mh_uVf5T1Hzpnf1oaJ2gTq1vljUHxjbQbkRmMy6f0AqxRi9U3StFBKdlFsgtaygIGSihQ9...<snip>... ",
    "expirationTimestamp": "2019-04-02T18:04:08Z"
  }
}
```

I want to point out a few things that come back in the response.. In the spec section one can see that it includes the list of audiences this token is valid for, as well as the lifetime of this token. If one were to try to use this token after 3600 seconds, or one hour, it would not be considered valid.

The other important item in this response is the token we requested. It is found in the `status` section. 

### TokenReview Request

Curl Template:

```shell
curl -X "POST" "https://{kubernetes API IP}:{kubernetes API Port}/apis/authentication.k8s.io/v1/tokenreviews" \
     -H 'Authorization: Bearer {your bearer token}' \
     -H 'Content-Type: application/json; charset=utf-8' \
     -d $'{
  "kind": "TokenReview",
  "apiVersion": "authentication.k8s.io/v1",
  "spec": {
    "token": "{token received in token request response}"
  }
}'
```

Example populated from my test cluster:

```bash
curl -X "POST" "https://192.168.2.173:6443/apis/authentication.k8s.io/v1/tokenreviews" \
     -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLWNxbng3Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiI2NzUwMGUzNC00NzM2LTExZTktODcxNi0wMDUwNTZiZjRiNDAiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06YWRtaW4tdXNlciJ9.kXpaaOkb8WnUBEiVUCvRbHexGhVxj3WY6m...<snip>...' \
     -H 'Content-Type: application/json; charset=utf-8' \
     -d $'{
  "kind": "TokenReview",
  "apiVersion": "authentication.k8s.io/v1",
  "spec": {
    "token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJhdWQiOlsidmF1bHQiXSwiZXhwIjoxNTUyNjc1Njk4LCJpYXQiOjE1NTI2NzUwOTgsImlzcyI6ImFwaSIsImt1YmVybmV0ZXMuaW8iOnsibmFtZXNwYWNlIjoiZGV2IiwicG9kIjp7Im5hbWUiOiJodHRwLXNlcnZpY2UtZXhhbXBsZS12Mi04NDg2OGNiNjU0LXE3ajhmIiwidWlkIjoiMmRkOTFlNDItNDczYi0xMWU5LTliYWQtMDA1MDU2YmY0YjQwIn0sInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJodHRwLXN2Yy10ZXN0IiwidWlkIjoiNGFmZGY0ZDAtNDZkMi0xMWU5LTg3MTYtMDA1MDU2YmY0YjQwIn19LCJuYmYiOjE1NTI2NzUwOTgsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZXY6aHR0cC1zdmMtdGVzdCJ9.WmQj9qakvOhYPdYfR5G8kL4r2--xd-Qw9osCZG2t9phNd5LtrvRMxXB3nZXciwfWpgZSUpc3CJOmYxvWAxdx9Xq...<snip>..."
  }
}'

```

As you can see above we are sending a `POST` request to the TokenReview endpoint with a JSON body that includes the token we want to validate. As with all kubernetes API requests we include a bearer token in an authorization header. This token was issued to our `token-server` pod and corresponds to the service account with the `ClusterRoleBinding` to allow `TokenReview` requests.

The response back would look like the following.

### TokenReview Response

```json
{
  "kind": "TokenReview",
    "apiVersion": "authentication.k8s.io/v1",
    "metadata": {
        "creationTimestamp": null
    },
    "spec": {
        "token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJhdWQiOlsidmF1bHQiXSwiZXhwIjoxNTUzNjI4ODYwLCJpYXQiOjE1NTM2MjgyNjAsImlzcyI6ImFwaSIsImt1YmVybmV0ZXMuaW8iOnsibmFtZXNwYWNlIjoiZGV2IiwicG9kIjp7Im5hbWUiOiJ0b2tlbi1jbGllbnQtNjVmNTc1YjU2NS10NDU2bSIsInVpZCI6IjBjNzc1NmQwLTRmZjgtMTFlOS05YzFkLTAwNTA1NmJmNGI0MCJ9LCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoiaHR0cC1zdmMtdGVzdCIsInVpZCI6IjRhZmRm....<snip>..."
    },
    "status": {
        "authenticated": true,
        "user": {
            "username": "system:serviceaccount:dev:http-svc-test",
            "uid": "4afdf4d0-46d2-11e9-8716-005056bf4b40",
            "groups": [
                "system:serviceaccounts",
                "system:serviceaccounts:dev",
                "system:authenticated"
            ],
            "extra": {
                "authentication.kubernetes.io/pod-name": [
                    "token-client-65f575b565-t456m"
                ],
                "authentication.kubernetes.io/pod-uid": [
                    "0c7756d0-4ff8-11e9-9c1d-005056bf4b40"
                ]
            }
        },
        "audiences": [
            "factors"
        ]
    }
}
```

The `status` portion of this response contains most of the data that will be useful for validating a token. The `authenticated` key is a simple boolean informing the requestor that this is an authenticated token. The audiences portion also lists the audiences this token is intended for. It is up to the developer to ensure they are the intended audience for this token. 

##  Example deployment

To demonstrate how this all comes together I will create two services that need to communicate. One, I'll call `token-client` and the other I'll call `token-server`, that returns factors of a provided number. A web client will send a request to `token-client` which will then make a service-to-service call to the `token-server` with its bound service account token as an auth header. The `token-server` will then validate the provided auth token against the TokenReview API and then respond with data or a 403 forbidden if the token is not valid.

The diagram below shows the communication flow of the demo applications

![TokenRequest Demo Flow](/images/tokenrequest@2x.png)

1. Container makes a request for a bound service account token via TokenRequest API. *In the demo, I am using volume projection to handle the fetching of the token on my behalf which is not pictured*
2. API returns a token
3. `token-client`  Pod makes service to service call to the `token-server` Pod
4. `token-server` Pod validates the auth token in HTTP request against the TokenReview API
5. API responds with validation data about the request token.
6. If the token is valid `token-server` responds to `token-client` with request payload.

Full manifests and example code can be found at [https://github.com/jpweber/tokenrequest-demo](https://github.com/jpweber/tokenrequest-demo)

For the `token-client` service there are two things that will be unique from a normal deployment. It needs to have a service account, as this does not work with the `default` service account. Token volume projection also needs to be configured.

### Token-Client Service Account

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app: token-client
  name: token-client-test
  namespace: token-demo
```

As you can see there is nothing special about this service account. We just need to create it and remember the name. Next are the PodSpec and volume definitions

### Token-Client PodSpec

``` yaml
    spec:
      serviceAccountName: token-client-test
      containers:
      - image: jpweber/tokenclient:0.2.3
        name: token-client
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 32Mi
        volumeMounts:
        - mountPath: /var/run/secrets/tokens
          name: factor-token

      volumes:
      - name: factor-token
        projected:
          sources:
          - serviceAccountToken:
              audience: factors
              expirationSeconds: 600
              path: factor-token
```

In the first line of the spec we are telling our containers to use the service account we created. About midway down is where the `volumeMounts` are specified. Here you specify the file path, and the name of the volume to be mounted at this path. One can mount these anywhere you prefer, I like to use `/var/run/secrets` because that is where kubernetes puts secrets by default. The last section at the bottom is `volumes`, which is where the projected volume is specified. If you have not used volumes in a pod before it is important to point out that the `name` field under volumes will be the name that is to be used under `volumeMounts`.

If you deployed using [my example](https://github.com/jpweber/tokenrequest-demo/blob/master/client/deploy.yaml) you can confirm that the TokenRequest and service account volume projection are working by checking the token file. The following command will work for other deployments, although you will need to modify the namespace, pod name, and path to the token where appropriate.

```shell
kubectl -n token-demo exec -ti <pod name> cat /var/run/secrets/tokens/factor-token
```

Which should provide output similar to the following.

``` shell
eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJhdWQiOlsiZmFjdG9ycyJdLCJleHAiOjE1NTM3MTc0NjYsImlhdCI6MTU1MzcxNjg2NiwiaXNzIjoiYXBpIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJ0b2tlbi1kZW1vIiwicG9kIjp7Im5hbWUiO
...<snip>...
J8t17gc6c9e9eIaU2NtwydSQoosDJkugkQDVV2SQDhVUdZU20mAKJkpBg9vo6LBmR4Q-c6mIseT7LyGhDTDpZhGqMYgkQ
```

You can further validate that this token is what you expect by putting decoding it with [https://jwt.io](https://jwt.io).

That covers requesting a bound service account token in the *client* application. Next, we need to see how we can validate that token from the *server* side.

The `token-server` needs a service account just like the `token-client` but we also need to create a `RoleBinding` to allow it to talk with the `TokenReview` API.

### Token-Server Service Account and Cluster RoleBinding

``` yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: token-reviewer
  namespace: token-demo
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: token-demo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: token-reviewer
  namespace: token-demo
```

Other than that the deployment manifest is totally standard. The example application then handles the token validation portion. 

Have a look at the demo in action with a request that fails auth and then one that succeeds. 

{{< asciinema key="238721"  preload="1"  loop="true">}}

When I first started exploring what TokenRequest API was all about I couldn't find something that tied all this information together and found myself going through kubernetes PRs and reading through the feature proposals to figure out how it all worked. I hope this has proved helpful in demonstrating what I think is a pretty powerful set of features in Kubernetes. 



## Reference Links

* service acount token volume project docs
    [https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection)

* service account volume projection proposal
    [https://github.com/mikedanese/community/blob/2bf41bd80a9a50b544731c74c7d956c041ec71eb/contributors/design-proposals/storage/svcacct-token-volume-source.md](https://github.com/mikedanese/community/blob/2bf41bd80a9a50b544731c74c7d956c041ec71eb/contributors/design-proposals/storage/svcacct-token-volume-source.md)

* TokenReview api docs. 
    [v1.TokenReview - /apis/authentication.k8s.io/v1 | REST API Reference | OKD Latest](https://docs.okd.io/latest/rest_api/apis-authentication.k8s.io/v1.TokenReview.html)

* TokenRequest proposal. 
    [community/bound-service-account-tokens.md at master · kubernetes/community · GitHub](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/auth/bound-service-account-tokens.md)

* github repo with example manifests and code. 
    [https://github.com/jpweber/tokenrequest-demo](https://github.com/jpweber/tokenrequest-demo)