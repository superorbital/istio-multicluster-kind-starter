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

## When You Are Done

Clean up after yourself with `./teardown.sh`

## Future Goals

This deployment could also be modified to support ambient multi-cluster.