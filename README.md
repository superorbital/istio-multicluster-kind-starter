# Istio MultiCluster Demo

This repository stands up the fastest and easiest demo in a local docker/kind environment
to manage a local kind cluster for an Istio Multi-Cluster deployment.

This enables you to experiment with the capabilities such as fault tolerance,
locality-aware routing, and gateway routing with ingress gateways, eastwest gateways,
and egress gateways.

The deployment structure for this configuration is in line with the most often used
production configuration, multi-primary istiod deployments, connected via gateway external
services, rather than direct pod communication.

## Dependencies

* `kind`
* `istioctl` - >=1.20
* `jq`
* `docker-compose`

### Helpful Tools

For running on mac, its useful to debug metallb services on Docker Desktop using
[`docker-mac-net-connect`](https://github.com/chipmk/docker-mac-net-connect).

I also installed the `vault` CLI locally to test the issuer.

## Getting Started

Clone this repository and run `./kind-demo.sh`

You should have a working demo up in less than 5 minutes.

To verify, go to the sleep pod in one of the clusters and run:

```bash
istioctl pc endpoints -n sample \
  $(kubectl get pod -n sample -l app=sleep -o jsonpath='{.items[0].metadata.name}') |\
  grep helloworld
```

If your output contains three entries, with one of them on port `15443` the multi-cluster
mesh with two clusters (`istio-so1` and `istio-so2`) on separate networks participating in the same mesh have been provisioned correctly.

### Debugging

Check that the services in the `istio-system` are in a healthy state and that metallb has
provisioned the IPs successfully.

## When You Are Done

Clean up after yourself with `./teardown.sh`

## Future Goals

This deployment could also be modified to support ambient multi-cluster.

## Configs

```
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: helloworld
  namespace: sample
spec:
  host: helloworld.sample.svc.cluster.local
  trafficPolicy:
    connectionPool:
      http:
        maxRequestsPerConnection: 1
    loadBalancer:
      simple: ROUND_ROBIN
      localityLbSetting:
        enabled: true
        failoverPriority:
          - "topology.istio.io/network"
          - "topology.kubernetes.io/region"
          - "topology.kubernetes.io/zone"
          - "kubernetes.io/hostname"
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 1m
```