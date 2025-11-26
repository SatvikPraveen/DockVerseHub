# Part 4: Distributed Tracing with Jaeger

## 🎯 Objective

Learn to debug applications using distributed traces.

## 🔍 Trace Fundamentals

### Anatomy of a Trace

```
Trace ID: abc123 (entire request flow)
├─ Span 1: GET /api/data (10ms total)
│  ├─ Span 1.1: validate_input (1ms)
│  ├─ Span 1.2: db_query (8ms)
│  └─ Span 1.3: format_response (1ms)
├─ Span 2: call_cache (5ms)
└─ Span 3: log_metrics (2ms)
```

**Trace** = Complete request flow across services

**Span** = Single operation within a trace

## 🚀 Access Jaeger

1. Open: http://localhost:16686
2. Service dropdown: "observability-demo"
3. Click: "Find Traces"

## 📊 Explore Traces

### View Trace Details

1. Click any trace
2. See timeline of all spans
3. Check operation names
4. View span attributes

### Common Attributes

- `http.method` - GET, POST, etc.
- `http.status_code` - 200, 404, 500
- `db.system` - postgres, mongodb
- `db.statement` - SQL query
- `error` - True if failed

## 🔎 Filter Traces

Use service filter:

```
Service: observability-demo

Operation: GET /api/data
Duration: > 100ms
Tags: error=true
```

This helps find:
- Slow requests (duration > threshold)
- Errors (error=true)
- Specific endpoints

## 📝 Exercise 1: Analyze Request Flow

### Task

Trace a request through the application:

1. Open Jaeger UI
2. Select service: observability-demo
3. Filter: Operation = "GET /api/data"
4. Click a trace

### Questions

Answer these:
- How many spans in the trace?
- What's the total duration?
- Which operation took longest?
- Were there any errors?
- What attributes are on each span?

### Solution Template

```markdown
# Trace Analysis

## Request Flow
[Describe the sequence of operations]

## Timeline
- Span 1: 10ms
- Span 2: 5ms
- Total: 15ms

## Performance Insights
[What took longest?]

## Errors
[Were there any error spans?]
```

## 📉 Performance Analysis

### Find Slow Requests

```
Service: observability-demo
Filter: duration > 500000000  # 500ms in nanoseconds
Click Find Traces
```

### Root Cause Analysis

For each slow trace:
1. View timeline
2. Identify slowest span
3. Check span attributes
4. Understand cause (DB, cache miss, etc.)

### Track Dependencies

Traces show service dependencies:
- Which services call each other
- How much latency each adds
- Error propagation

## 🎯 Exercise 2: Error Investigation

### Task

Investigate error traces:

1. In Jaeger, filter for errors
2. Find GET /api/error requests
3. Examine the error span

### Questions

- What error type occurred?
- At which point in the trace?
- What span attributes indicate the error?
- How could this be prevented?

## 🔗 Trace Context Propagation

### How Tracing Works

```
Client Request
└─ Trace Header: uber-trace-id=abc123:def456:0:1
   ├─ Service A receives header
   ├─ Creates spans for operations
   ├─ Calls Service B with header
   │  └─ Service B receives same trace ID
   │     └─ Creates child spans
   └─ Jaeger collects all spans
      └─ Reconstructs full trace
```

## 📊 Latency Analysis

### P95 Latency

Find requests at 95th percentile (very slow):

1. In Jaeger: Sort by Duration (longest first)
2. Look at top 5% slowest requests
3. What's the duration? (P95)
4. Why were they slow?

Typical findings:
- Database queries slow
- Cache misses
- External API timeouts

## 💾 Trace Storage

### Check Storage Backend

Default: Badger (embedded)

For production, use:
- Elasticsearch
- Cassandra
- S3

Configuration in docker-compose.yml:
```yaml
BADGER_EPHEMERAL: "false"
BADGER_DIRECTORY_VALUE: "/badger/data"
```

## 🎓 Best Practices for Tracing

1. **Name operations clearly**
   ```
   Good: "user-service:get-user"
   Bad: "handler"
   ```

2. **Add relevant attributes**
   ```python
   span.set_attribute("user.id", user_id)
   span.set_attribute("request.size", len(data))
   ```

3. **Track errors**
   ```python
   span.set_attribute("error", True)
   span.set_attribute("error.message", str(exception))
   ```

4. **Monitor trace volume**
   - High volume = High cost
   - Use sampling in production

## ✅ Verification Steps

1. Jaeger running: http://localhost:16686
2. Service visible: "observability-demo"
3. Traces being collected
4. Can filter by duration
5. Can view span details

## 🧪 Generate Trace Load

```bash
# Generate various request types
while true; do
  curl http://localhost:5000/api/data
  curl http://localhost:5000/api/slow
  curl http://localhost:5000/api/error
  sleep 1
done

# Watch traces appear in Jaeger in real-time
```

## 📋 Exercise Summary

Complete these tasks:

- [ ] Access Jaeger UI
- [ ] Select observability-demo service
- [ ] View a successful trace
- [ ] Analyze trace timeline
- [ ] Find a slow request (duration > 500ms)
- [ ] Find an error trace
- [ ] Identify root cause of errors
- [ ] Check P95 latency

---

## Next Steps

Proceed to **Part 5: Incident Response & Alerts**

