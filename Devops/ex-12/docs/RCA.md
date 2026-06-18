# Root Cause Analysis (RCA)
**Incident: Worker Node NotReady via DiskPressure**

## Executive Summary
On 2026-06-18, the Kubernetes agent node (`k3d-ex12-agent-0`) transitioned to `NotReady` status, causing microservice degradation and pod evictions. The root cause was identified as an **application-level retry storm** from the `payment-service` that exhausted the node's disk space (`nodefs`), triggering Kubelet's eviction manager and setting the `DiskPressure=True` condition.

---

## Incident Timeline
1. **15:30 UTC** - An operator applied incorrect database credentials to the Kubernetes Secret `db-credentials` (simulated database communication failure).
2. **15:31 UTC** - The `payment-service` was restarted and failed to connect to PostgreSQL.
3. **15:32 UTC** - The load generator script ramped up order volume. The `frontend` and `order-service` routed payment requests to `payment-service`.
4. **15:32:05 UTC** - For every incoming transaction request, `payment-service` initiated a rapid connection retry loop (10 retries, 50ms delay) to the database. Each failed connection attempt logged a verbose stack trace (approx. 8KB per error log).
5. **15:33 UTC** - The rate of log ingestion exceeded the node's log storage capacity. The `/var/log` directory reached 100% capacity (80MB limit).
6. **15:33:15 UTC** - Kubelet detected `nodefs` available space was under the 10% threshold and set the `DiskPressure=True` condition.
7. **15:33:20 UTC** - Kubelet started evicting low-priority/best-effort pods.
8. **15:33:30 UTC** - The node entered the `NotReady` state, and cluster communications degraded.

---

## Root Cause Analysis
The incident was a result of two intersecting issues:
1. **Aggressive Retry Strategy without Backoff**:
   The `payment-service` retry settings used a fixed 50ms delay with a retry limit of 10. When database connectivity failed, this created a high-frequency retry storm.
2. **Extremely Verbose Error Logging**:
   Each failed retry printed a massive JSON-structured log payload containing:
   * Full multi-line Python traceback
   * Redacted database configurations and environment parameters
   * HTTP request details
   This verbose logging produced ~80KB of log output per failed transaction. At 100+ requests per second, log volume reached several megabytes per second, quickly filling up `/var/log`.
3. **Lack of Log Rotation and Limits**:
   The local container runtime and Kubelet were not configured with log limits (`containerLogMaxSize`), allowing container standard output logs to grow unbounded until the disk was completely full.

---

## Recovery Actions taken
1. Stopped the incoming traffic storm by scaling the load generator to 0.
2. Fixed the secret credentials to allow the `payment-service` to connect to PostgreSQL successfully.
3. Cleared the disk usage by truncating the container log files (`/var/log/pods/*/*/*.log`) to 0 bytes, releasing the disk space immediately without restarting Docker/Kubelet.
4. Restarted the `payment-service` to apply the fixed credentials.
5. The `DiskPressure` condition cleared, and the node returned to the `Ready` state.

---

## Preventative Actions
1. **Log Rotation Configurations**:
   Configure container log limits inside the Kubelet configuration or Docker daemon:
   * `containerLogMaxSize: "10Mi"`
   * `containerLogMaxFiles: 3`
2. **Exponential Backoff and Jitter**:
   Modify the application retry strategy to use exponential backoff (e.g., doubling the retry delay on each step: 100ms, 200ms, 400ms...) and add randomized jitter to prevent synchronized retry storms.
3. **Log Sanitization and Volume Throttling**:
   Limit the frequency of logging full stack traces in production (e.g., log full trace only on the final failure, not on every intermediate retry attempt).
4. **Eviction Threshold Tuning**:
   Configure explicit Kubelet eviction thresholds:
   `--eviction-hard=nodefs.available<5%`
