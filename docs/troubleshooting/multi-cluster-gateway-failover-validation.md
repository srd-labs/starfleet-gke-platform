# Multi-Cluster Gateway Failover and Failback Validation

## Objective

Validate that the GKE Multi-Cluster Gateway automatically routes traffic
between the Alpha and Delta clusters while maintaining the same global
frontend IP.

``` text
                       Internet
                          |
                          v
                 34.117.211.201
                          |
                          v
              Multi-Cluster Gateway
                    /             \
                   /               \
                  v                 v
        enterprise-gke-alpha   enterprise-gke-delta
           us-central1-a          us-east1-b
                  \                 /
                   Navigation Service
```

## 1. Validate Delta Directly

Before testing failover, validate Delta independently using its existing
LoadBalancer IP:

``` bash
curl -s http://35.196.67.21/
```

Observed:

``` json
{"quadrant":"delta","service":"starfleet-navigation-service","status":"operational"}
```

This confirmed that the Delta backend was healthy and capable of
receiving failover traffic.

## 2. Validate Normal Global Routing

Test the Multi-Cluster Gateway global frontend IP:

``` bash
curl -s http://34.117.211.201/
```

Observed:

``` json
{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}
```

Multiple requests confirmed Alpha was the preferred backend under normal
conditions:

``` bash
for i in {1..10}; do
  curl -s http://34.117.211.201/
  echo
  sleep 2
done
```

Observed:

``` text
{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}
{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}
{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}
...
```

## 3. Simulate Alpha Service Failure

Switch the Kubernetes context to Alpha:

``` bash
gcloud container clusters get-credentials enterprise-gke-alpha \
  --zone=us-central1-a \
  --project=starfleet-gke-platform-lab
```

Temporarily remove the Alpha Navigation backend:

``` bash
kubectl scale deployment starfleet-navigation-service --replicas=0
```

Observed:

``` text
deployment.apps/starfleet-navigation-service scaled
```

This simulated an application/backend outage in Alpha without destroying
the cluster or modifying the Gateway configuration.

## 4. Validate Automatic Failover to Delta

Test the same global IP repeatedly:

``` bash
for i in {1..10}; do
  curl -s http://34.117.211.201/
  echo
  sleep 2
done
```

Observed:

``` text
{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"delta","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"delta","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"delta","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"delta","service":"starfleet-navigation-service","status":"operational"}
```

The first request still reached Alpha while backend health information
was converging. Subsequent requests were successfully served by Delta.

Most importantly, the client continued using the same global IP:

``` text
34.117.211.201
```

No client-side endpoint change was required.

## 5. Restore Alpha

Restore the Alpha Navigation deployment:

``` bash
kubectl scale deployment starfleet-navigation-service --replicas=2
```

Wait for the deployment:

``` bash
kubectl rollout status deployment/starfleet-navigation-service
```

Verify the Alpha pods:

``` bash
kubectl get pods \
  -l app=starfleet-navigation-service \
  -o wide
```

## 6. Validate Automatic Failback

Test the same global IP again:

``` bash
for i in {1..10}; do
  curl -s http://34.117.211.201/
  echo
  sleep 2
done
```

Observed:

``` text
{"quadrant":"delta","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}

{"quadrant":"alpha","service":"starfleet-navigation-service","status":"operational"}
```

The first request was still routed to Delta while Alpha was returning to
the healthy backend pool. Subsequent requests returned to Alpha.

## Validation Result

``` text
Normal:
Client -> 34.117.211.201 -> Alpha [PASS]

Alpha Navigation unavailable:
Client -> 34.117.211.201 -> Delta [PASS]

Alpha restored:
Client -> 34.117.211.201 -> Alpha [PASS]
```

**Result: PASS**

The test demonstrates that the GKE Multi-Cluster Gateway can maintain a
single global frontend endpoint while routing requests to a healthy
Navigation backend in another cluster when the preferred backend becomes
unavailable, and subsequently resume routing to Alpha after recovery.

The `quadrant` field in the application response provides clear evidence
of which cluster served each request.
