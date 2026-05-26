#!/usr/bin/env python3
# scripts/finops/hikaricp-calculator.py
# WHY this calculation matters:
# Each Spring Boot pod opens a HikariCP connection pool to PostgreSQL.
# Aurora PostgreSQL r6g.large: max_connections = 1708 (formula: GREATEST(DBInstanceClassMemory/9531392, 5000))
# r6g.large has 16GB RAM: 16384MB × 1024KB × 1024B / 9531392 bytes = 1755 → but Aurora caps at 1708
# If you exceed 1708 connections: ERROR: remaining connection slots are reserved for non-replication superuser
# This is the most common production Aurora failure at scale.

import math

# Configuration
AURORA_INSTANCE = "db.r6g.large"
MAX_CONNECTIONS = 1708          # Aurora r6g.large limit
SAFETY_MARGIN = 0.80            # Keep 20% headroom for admin connections, replication, monitoring
POOL_SIZE_PER_POD = 10          # HikariCP maximumPoolSize per pod (default)
SERVICES_COUNT = 4              # gateway, user, product, order

safe_connections = math.floor(MAX_CONNECTIONS * SAFETY_MARGIN)
max_replicas_per_service = math.floor(safe_connections / SERVICES_COUNT / POOL_SIZE_PER_POD)

print(f"""
╔════════════════════════════════════════════════════════════════╗
║         HikariCP ↔ Aurora Connection Pool Calculator           ║
╠════════════════════════════════════════════════════════════════╣
║  Aurora Instance:        {AURORA_INSTANCE:<33} ║
║  max_connections:        {MAX_CONNECTIONS:<33} ║
║  Safety margin (80%):   {safe_connections:<33} ║
║  Services sharing pool: {SERVICES_COUNT:<33} ║
║  Pool size per pod:      {POOL_SIZE_PER_POD:<33} ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  Formula: floor(1708 × 0.8 / 4 services / 10 per pod)        ║
║         = floor({safe_connections} / {SERVICES_COUNT} / {POOL_SIZE_PER_POD})                         ║
║         = {max_replicas_per_service} replicas max per service                      ║
║                                                                ║
║  HPA maxReplicas MUST be ≤ {max_replicas_per_service} per service              ║
║  Setting maxReplicas > {max_replicas_per_service} will cause:                  ║
║    → Connection pool exhaustion                                ║
║    → "remaining connection slots reserved" error               ║
║    → Cascading failures across all 4 services                 ║
╠════════════════════════════════════════════════════════════════╣
""")

# Show what happens at different replica counts
print("  Replica Count Analysis:")
print("  Replicas | Total Connections | Status")
print("  ─────────┼───────────────────┼────────")
for replicas in [10, 20, 30, 34, 40, 50]:
    total = replicas * SERVICES_COUNT * POOL_SIZE_PER_POD
    pct = (total / MAX_CONNECTIONS) * 100
    if total <= safe_connections:
        status = "✅ SAFE"
    elif total <= MAX_CONNECTIONS:
        status = "⚠️  RISKY (<20% headroom)"
    else:
        status = "❌ BREACH"
    print(f"  {replicas:<8} | {total:<17} | {pct:.0f}% {status}")

print(f"""
  ╚════════════════════════════════════════════════════════════════╝

  Production Answer for Interviewers:
  "Our HPA maxReplicas is capped at {max_replicas_per_service} per service.
   Here's the math: Aurora r6g.large max_connections = 1708.
   We hold 20% in reserve: 1708 × 0.8 = {safe_connections} usable.
   Divided across 4 services × 10 connections per pod = {max_replicas_per_service} max replicas per service.
   Our Infrastructure page shows this calculator live — slide the replica
   slider past {max_replicas_per_service} and it turns red with the exact breach calculation."
""")

if __name__ == "__main__":
    pass