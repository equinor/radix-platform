# Scaling Docker build hosts

If multiple build hosts are used (as they will be, when multiple projects/builds are ongoing), there is a need to ensure that multiple `docker` commands within a build (e.g. `docker build`, `docker push`) are run on the same host. A possibility is to use session affinity [docs](https://kubernetes.io/docs/concepts/services-networking/service/), aka sticky sessions, whereby we guarantee that connections from one Jenkins slave pod is routed to the same Docker pod for at least a few hours (default 4 hours stickiness).

To use build cache reliably between between builds, we would either have to guarantee project-to-build-host mapping (so the host would have a local cache) or share the cache between all hosts. The [standard way](https://blog.nimbleci.com/2016/11/17/whats-coming-in-docker-1-13/#cache-layers-when-building) to implement the latter solution is to make use of the `----cache-from` parameter for `docker build`: basically, we can use a previously-registered image as a trusted source for caching (i.e. we would pull the last-built image from the registry).

To be explored: performance of puling from the registry for cache usage; possibilities of speeding this up if necessary.
