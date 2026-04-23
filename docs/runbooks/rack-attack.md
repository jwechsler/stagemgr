# Rack-Attack Operations Runbook

Production monitoring and incident-response guide for the rate limiter installed at `config/initializers/rack_attack.rb`.

## Conventions

Commands are shown with the Docker Compose layout used in staging. On the production host set these once per shell so the snippets below work verbatim:

```bash
export COMPOSE='docker compose -f /path/to/site/docker-compose.yml'
alias redis-cli="$COMPOSE exec -T redis redis-cli"
alias rails-runner="$COMPOSE exec -T stagemgr bash -c 'cd /var/www/stagemgr && bundle exec rails runner'"
```

Adjust paths to wherever `site/docker-compose.yml` lives on the production box.

## At deploy — one-time verification

Run all four. All should return the expected output. If any fail, rate limiting is not active.

### 1. Middleware is registered

```bash
rails-runner 'puts Rails.application.middleware.middlewares.map(&:name).grep(/Attack/).first'
```

**Expected:** `Rack::Attack`

### 2. Redis connectivity

```bash
rails-runner 'puts Rack::Attack.cache.store.redis.ping'
```

**Expected:** `PONG`

### 3. Throttles loaded

```bash
rails-runner 'puts Rack::Attack.throttles.keys.inspect'
```

**Expected:** `["req/ip", "logins/ip", "orders-post/ip"]`

### 4. `maxmemory-policy` is safe for Resque

```bash
redis-cli config get maxmemory-policy
```

**Expected:** `noeviction` or `volatile-lru`. Anything starting with `allkeys-` is unsafe — it can evict pending Resque jobs silently. Fix with:

```bash
redis-cli config set maxmemory-policy noeviction
redis-cli config rewrite
```

## Day-to-day monitoring

### Tail throttle events live

```bash
$COMPOSE exec -T stagemgr tail -F /var/www/stagemgr/log/production.log | grep '\[rack-attack\]'
```

Lines look like:

```
[rack-attack] throttled matched=logins/ip ip=203.0.113.99 path=/tickets/user_session
```

### How many distinct actors are currently tracked

```bash
redis-cli --scan --pattern 'stagemgr:production:rack-attack:*' | wc -l
```

Normal steady state is tens to low hundreds. A sudden jump to thousands suggests a distributed probe.

### Top throttled IPs in the last hour

```bash
$COMPOSE exec -T stagemgr bash -c "grep '\[rack-attack\] throttled' /var/www/stagemgr/log/production.log \
  | tail -5000 \
  | grep -oE 'ip=[0-9.]+' \
  | sort | uniq -c | sort -rn | head -20"
```

Run this after any alert. IPs appearing repeatedly are candidates for the permanent blocklist (see Incident Response).

### Redis errors from rack-attack

If rack-attack loses Redis it fails **open** — requests are not throttled, and warnings log instead of erroring. Watch for them:

```bash
$COMPOSE exec -T stagemgr grep 'rack-attack cache error' /var/www/stagemgr/log/production.log | tail
```

Any hits here mean the rate limiter was temporarily disabled. Investigate Redis health.

## Inspecting a specific IP

### See current counters for an IP

```bash
redis-cli --scan --pattern 'stagemgr:production:rack-attack:*203.0.113.99*'
```

Then for each key returned:

```bash
redis-cli get <key>
redis-cli ttl <key>
```

The integer is the request count in the current window; the TTL is seconds until reset.

### Unblock a legitimate user who got throttled

Delete their counter keys — they can retry immediately:

```bash
redis-cli --scan --pattern 'stagemgr:production:rack-attack:*203.0.113.99*' | xargs redis-cli del
```

## Incident response

### Persistent attacker — permanent block

Add an explicit blocklist entry to `config/initializers/rack_attack.rb` and deploy. Example:

```ruby
Rack::Attack.blocklist('persistent-probe-source') do |req|
  ['149.50.116.31', '198.51.100.42'].include?(req.ip)
end
```

Blocklisted requests return 403 without touching the rate limit counters — cheaper than throttling.

### Ephemeral block without a deploy

For a fast, no-deploy block, push an IP directly into Redis under the key rack-attack checks for its Fail2Ban-style blocklist. Expires automatically:

```bash
# Block 1.2.3.4 for 1 hour
rails-runner 'Rack::Attack.cache.store.write("rack::attack:allow2ban:ban:1.2.3.4", 1, expires_in: 3600)'
```

Verify by making a request from that IP — should return 403. This is a stopgap; follow up with a proper blocklist rule in the initializer if the block needs to stick.

### False positives — legitimate traffic tripping a throttle

The two likely causes:

1. **Kiosk or venue NAT** — many patrons sharing one public IP. Bump the limit on `req/ip`, or switch the discriminator to session id for that path. Edit the initializer, deploy, restart Passenger.
2. **Single-page app making burst calls** — check whether the throttle is `req/ip` or `orders-post/ip`. If it's the orders throttle, the limit is 30 POSTs/min which should comfortably accommodate a checkout flow; investigate whether a client-side bug is flooding.

### Full reset (nuclear option)

If a bad rule is causing a broad outage and you can't deploy a fix immediately, disable rack-attack at runtime:

```bash
rails-runner 'Rack::Attack.enabled = false'
```

Note this only affects the single worker the `rails runner` command hits. To disable across all Passenger workers, touch `tmp/restart.txt` after adding `Rack::Attack.enabled = false` somewhere in the initializer, or comment the `require 'rack/attack'` line and restart.

Also works: flush **just** the rack-attack keys without touching Resque:

```bash
redis-cli --scan --pattern 'stagemgr:production:rack-attack:*' | xargs redis-cli del
```

## Current throttle configuration

Reference — copy of what's in `config/initializers/rack_attack.rb` at time of writing:

| Name | Limit | Window | Scope |
|---|---|---|---|
| `req/ip` | 300 | 5 min | All requests, excludes `/assets`, `/packs`, `/favicon` |
| `logins/ip` | 10 | 1 min | POST to `/user_session` or `/login` |
| `orders-post/ip` | 30 | 1 min | POST to `/ticket_orders`, `/donation_orders`, `/membership_orders`, `/flex_pass_orders` |

Throttled responses include `Retry-After`, `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` headers.

## Related configuration

- Exception-notifier ignore list: `config/environments/production.rb` — suppresses inbox spam from malformed-URL probes.
- Redis URL: `ENV['REDIS_URL']`, shared with Resque. Same instance, key namespace `stagemgr:<env>:rack-attack`.
- Error handler: on Redis failure, rack-attack fails **open** (requests proceed unthrottled) and logs `rack-attack cache error` at WARN.
