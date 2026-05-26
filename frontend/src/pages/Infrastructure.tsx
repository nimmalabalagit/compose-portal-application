import { useState } from 'react'
import { Server, Shield, GitBranch, Activity, Zap, Database } from 'lucide-react'

// Realistic pod data matching the lab architecture:
// 2 replicas per service, spread across 3 AZs (topologySpreadConstraints)
const PODS = [
  { service: 'gateway-service', pod: 'gateway-service-7d9f6b-xk2p9', node: 'ip-10-0-11-45', status: 'RUNNING', restarts: 0, cpu: '45m', mem: '380Mi', az: 'ap-south-1a' },
  { service: 'gateway-service', pod: 'gateway-service-7d9f6b-m3nv8', node: 'ip-10-0-12-23', status: 'RUNNING', restarts: 0, cpu: '52m', mem: '395Mi', az: 'ap-south-1b' },
  { service: 'user-service',    pod: 'user-service-5c8b4f-p9qr2',    node: 'ip-10-0-11-45', status: 'RUNNING', restarts: 1, cpu: '38m', mem: '290Mi', az: 'ap-south-1a' },
  { service: 'user-service',    pod: 'user-service-5c8b4f-k7wt1',    node: 'ip-10-0-13-67', status: 'RUNNING', restarts: 0, cpu: '41m', mem: '310Mi', az: 'ap-south-1c' },
  { service: 'product-service', pod: 'product-service-6f7c8d-n2ms5',  node: 'ip-10-0-12-23', status: 'RUNNING', restarts: 0, cpu: '29m', mem: '265Mi', az: 'ap-south-1b' },
  { service: 'product-service', pod: 'product-service-6f7c8d-r4vp8',  node: 'ip-10-0-11-45', status: 'RUNNING', restarts: 0, cpu: '33m', mem: '271Mi', az: 'ap-south-1a' },
  { service: 'order-service',   pod: 'order-service-8a9b2e-x5lm3',   node: 'ip-10-0-13-67', status: 'RUNNING', restarts: 2, cpu: '62m', mem: '412Mi', az: 'ap-south-1c' },
  { service: 'order-service',   pod: 'order-service-8a9b2e-y7np6',   node: 'ip-10-0-12-23', status: 'RUNNING', restarts: 0, cpu: '57m', mem: '398Mi', az: 'ap-south-1b' },
]

const NODES = [
  { name: 'ip-10-0-11-45', type: 'm5.xlarge', capacity: 'SPOT',      cpu: '62%', mem: '71%', pods: 12, provisionedIn: '47s' },
  { name: 'ip-10-0-12-23', type: 'm5.large',  capacity: 'ON-DEMAND', cpu: '44%', mem: '58%', pods: 9,  provisionedIn: 'system' },
  { name: 'ip-10-0-13-67', type: 'c5.xlarge', capacity: 'SPOT',      cpu: '55%', mem: '63%', pods: 11, provisionedIn: '31s' },
]

const IRSA = [
  { sa: 'gateway-service-sa', role: 'compose-portal-gateway-irsa-prod', perms: 'SSM GetParameter, ElastiCache Connect' },
  { sa: 'user-service-sa',    role: 'compose-portal-user-irsa-prod',    perms: 'SSM GetParameter /compose-portal/user/*' },
  { sa: 'product-service-sa', role: 'compose-portal-product-irsa-prod', perms: 'SSM GetParameter, ElastiCache Connect' },
  { sa: 'order-service-sa',   role: 'compose-portal-order-irsa-prod',   perms: 'SSM GetParameter, SNS Publish' },
]

const HPA = [
  { service: 'gateway-service', current: 2, desired: 2, max: 10, cpuTarget: '60%', cpuActual: '48%' },
  { service: 'user-service',    current: 2, desired: 2, max: 8,  cpuTarget: '60%', cpuActual: '39%' },
  { service: 'product-service', current: 2, desired: 2, max: 8,  cpuTarget: '60%', cpuActual: '31%' },
  { service: 'order-service',   current: 2, desired: 3, max: 8,  cpuTarget: '60%', cpuActual: '62%' },
]

// HikariCP Pool Math (the critical interview question)
// Aurora r6g.large max_connections = 1708
// maxReplicas_safe = floor(max_connections × 0.8 / num_services / pool_size)
// floor(1708 × 0.8 / 4 / 10) = floor(34.16) = 34 max replicas per service
const AURORA_MAX = 1708
const N_SERVICES  = 4
const POOL_SIZE   = 10

function poolCalc(replicas: number) {
  const total = replicas * N_SERVICES * POOL_SIZE
  const pct   = (total / AURORA_MAX) * 100
  return {
    total,
    pct,
    status: pct < 60 ? 'GREEN' : pct < 85 ? 'AMBER' : 'RED',
  }
}

export default function InfrastructurePage() {
  const [replicas, setReplicas] = useState(2)
  const pool = poolCalc(replicas)

  return (
    <div className="space-y-6">

      <div>
        <h1 className="font-display text-2xl font-bold text-slate-100">Infrastructure Health</h1>
        <p className="text-xs font-mono text-slate-500 mt-0.5">
          EKS compose-portal-eks v1.32 · Karpenter v0.37 · 371056712467 · ap-south-1
        </p>
      </div>

      {/* ── Pod health table ──────────────────────────────────────── */}
      <div className="card-dark overflow-hidden">
        <div className="flex items-center gap-2 px-5 py-4 border-b border-slate-700">
          <Server className="w-4 h-4 text-cyan-400" />
          <h2 className="font-display font-semibold text-slate-200">Pod Health</h2>
          <span className="font-mono text-xs text-slate-500">— 8 pods across 3 AZs</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                {['Pod Name', 'Service', 'AZ', 'Status', 'Restarts', 'CPU', 'Memory'].map((h) => (
                  <th key={h} className="text-left font-mono text-xs text-slate-500 px-4 py-3 uppercase">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {PODS.map((pod, idx) => (
                <tr
                  key={pod.pod}
                  className="hover:bg-slate-800/40 transition-colors"
                  style={{ borderBottom: idx < PODS.length - 1 ? '1px solid var(--border-muted)' : 'none' }}
                >
                  <td className="px-4 py-3 font-mono text-xs text-cyan-400">{pod.pod}</td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-400">{pod.service}</td>
                  <td className="px-4 py-3">
                    <span className="font-mono text-xs px-1.5 py-0.5 rounded"
                          style={{ background: 'rgba(0,212,255,0.08)', color: '#00D4FF', fontSize: '10px' }}>
                      {pod.az}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="status-running font-mono text-xs px-2 py-0.5 rounded-full">{pod.status}</span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">
                    <span className={pod.restarts > 0 ? 'text-amber-400' : 'text-slate-500'}>
                      {pod.restarts}
                    </span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-400">{pod.cpu}</td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-400">{pod.mem}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="px-5 py-3 border-t border-slate-800 font-mono text-xs text-slate-500">
          topologySpreadConstraints maxSkew=1 · AZ spread → no single-AZ failure takes down a service
        </div>
      </div>

      {/* ── Karpenter nodes + IRSA ────────────────────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">

        <div className="card-dark p-5">
          <div className="flex items-center gap-2 mb-4">
            <Zap className="w-4 h-4 text-amber-400" />
            <h2 className="font-display font-semibold text-slate-200">Karpenter Nodes</h2>
          </div>
          <div className="space-y-3">
            {NODES.map((node) => (
              <div key={node.name} className="p-3 rounded-lg"
                   style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)' }}>
                <div className="flex items-center justify-between mb-2">
                  <span className="font-mono text-xs text-slate-300">{node.name}</span>
                  <span
                    className="font-mono text-xs px-2 py-0.5 rounded-full"
                    style={{
                      background: node.capacity === 'SPOT' ? 'rgba(245,158,11,0.1)' : 'rgba(16,185,129,0.1)',
                      border: node.capacity === 'SPOT' ? '1px solid rgba(245,158,11,0.25)' : '1px solid rgba(16,185,129,0.25)',
                      color: node.capacity === 'SPOT' ? '#F59E0B' : '#10B981',
                    }}
                  >
                    {node.capacity}
                  </span>
                </div>
                <div className="flex items-center gap-3 text-xs font-mono text-slate-500">
                  <span>{node.type}</span>
                  <span>CPU {node.cpu}</span>
                  <span>Mem {node.mem}</span>
                  <span>{node.pods} pods</span>
                  {node.capacity === 'SPOT' && (
                    <span className="text-amber-400">⚡ in {node.provisionedIn}</span>
                  )}
                </div>
              </div>
            ))}
          </div>
          <div className="mt-3 font-mono text-xs text-slate-500">
            70% Spot target · consolidateAfter=30s · $67→$28/month (58% reduction)
          </div>
        </div>

        <div className="card-dark p-5">
          <div className="flex items-center gap-2 mb-4">
            <Shield className="w-4 h-4 text-emerald-400" />
            <h2 className="font-display font-semibold text-slate-200">IRSA Mapping</h2>
          </div>
          <div className="space-y-3">
            {IRSA.map((i) => (
              <div key={i.sa} className="p-3 rounded-lg"
                   style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)' }}>
                <div className="font-mono text-xs text-cyan-400 mb-0.5">{i.sa}</div>
                <div className="font-mono text-xs text-slate-500 mb-0.5">→ {i.role}</div>
                <div className="font-mono text-xs" style={{ color: 'rgba(16,185,129,0.8)' }}>{i.perms}</div>
              </div>
            ))}
          </div>
          <div className="mt-3 font-mono text-xs text-slate-500">
            OIDC WebIdentity → STS AssumeRoleWithWebIdentity → temp creds
            <br />No static keys anywhere. Token at /var/run/secrets/eks.amazonaws.com/
          </div>
        </div>
      </div>

      {/* ── HPA status ───────────────────────────────────────────── */}
      <div className="card-dark p-5">
        <div className="flex items-center gap-2 mb-4">
          <Activity className="w-4 h-4 text-cyan-400" />
          <h2 className="font-display font-semibold text-slate-200">HPA Status</h2>
        </div>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          {HPA.map((hpa) => {
            const scaling = hpa.current !== hpa.desired
            return (
              <div key={hpa.service} className="p-3.5 rounded-lg"
                   style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)' }}>
                <div className="font-mono text-xs text-slate-400 mb-2">{hpa.service}</div>
                <div className="flex items-baseline gap-1 mb-1">
                  <span className="metric-number text-xl">{hpa.current}</span>
                  <span className="text-slate-600 font-mono text-xs">/{hpa.max}</span>
                  {scaling && <span className="text-xs text-amber-400 font-mono">→{hpa.desired}</span>}
                </div>
                <div className="font-mono text-xs text-slate-500">
                  CPU {hpa.cpuActual} / target {hpa.cpuTarget}
                </div>
                {scaling && (
                  <div className="mt-1 text-xs text-amber-400 font-mono">⚡ scaling up</div>
                )}
              </div>
            )
          })}
        </div>
        <div className="mt-3 font-mono text-xs text-slate-500">
          metrics-server required — without it: &lt;unknown&gt;/60% → HPA silent failure (Problem 7)
        </div>
      </div>

      {/* ── HikariCP Pool Math Calculator ────────────────────────── */}
      <div className="card-dark p-5">
        <div className="flex items-center gap-2 mb-2">
          <Database className="w-4 h-4 text-cyan-400" />
          <h2 className="font-display font-semibold text-slate-200">HikariCP Pool Math Calculator</h2>
          <span className="font-mono text-xs text-slate-500">— the critical K8s interview topic</span>
        </div>

        <div
          className="mb-5 p-3 rounded-lg font-mono text-xs"
          style={{ background: 'var(--bg-elevated)', border: '1px solid rgba(0,212,255,0.15)' }}
        >
          <div className="text-slate-400 mb-1">
            Formula: maxReplicas_safe = floor(max_connections × 0.8 / num_services / pool_size)
          </div>
          <div style={{ color: '#00D4FF' }}>
            Aurora r6g.large max_connections={AURORA_MAX} →
            floor({AURORA_MAX} × 0.8 / {N_SERVICES} svcs / {POOL_SIZE} pool) =&nbsp;
            <strong>34 max replicas per service</strong>
          </div>
          <div className="text-slate-600 mt-1">
            Oracle analogy: same math as Oracle PROCESSES / SESSIONS in init.ora — both define connection ceiling
          </div>
        </div>

        <div className="space-y-5">
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="font-mono text-xs text-slate-400">Replicas per service</label>
              <span className="metric-number text-xl">{replicas}</span>
            </div>
            <input
              type="range" min={1} max={50} value={replicas}
              onChange={(e) => setReplicas(Number(e.target.value))}
              className="w-full cursor-pointer"
            />
            <div className="flex justify-between font-mono text-xs text-slate-600 mt-1">
              <span>1</span>
              <span className="text-amber-400">34 (safe ceiling)</span>
              <span className="text-rose-400">50 (breach!)</span>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4">
            <div className="p-3 rounded-lg text-center"
                 style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)' }}>
              <div className="font-mono text-xs text-slate-500 mb-1">Total Connections</div>
              <div className="metric-number text-2xl">{pool.total}</div>
              <div className="font-mono text-xs text-slate-600 mt-1">
                {replicas} × {N_SERVICES} × {POOL_SIZE}
              </div>
            </div>
            <div className="p-3 rounded-lg text-center"
                 style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)' }}>
              <div className="font-mono text-xs text-slate-500 mb-1">Aurora Utilization</div>
              <div
                className="text-2xl font-bold font-mono"
                style={{ color: pool.status === 'GREEN' ? '#10B981' : pool.status === 'AMBER' ? '#F59E0B' : '#F43F5E' }}
              >
                {pool.pct.toFixed(1)}%
              </div>
              <div className="font-mono text-xs text-slate-600 mt-1">of {AURORA_MAX} max</div>
            </div>
            <div
              className="p-3 rounded-lg text-center"
              style={{
                background: pool.status === 'GREEN' ? 'rgba(16,185,129,0.08)' :
                            pool.status === 'AMBER' ? 'rgba(245,158,11,0.08)' : 'rgba(244,63,94,0.08)',
                border: `1px solid ${pool.status === 'GREEN' ? 'rgba(16,185,129,0.25)' :
                          pool.status === 'AMBER' ? 'rgba(245,158,11,0.25)' : 'rgba(244,63,94,0.25)'}`,
              }}
            >
              <div className="font-mono text-xs text-slate-500 mb-1">Status</div>
              <div
                className="text-2xl font-bold font-mono"
                style={{ color: pool.status === 'GREEN' ? '#10B981' : pool.status === 'AMBER' ? '#F59E0B' : '#F43F5E' }}
              >
                {pool.status}
              </div>
              {pool.status === 'RED' && (
                <div className="text-xs text-rose-400 font-mono mt-1">CONNECTION BREACH</div>
              )}
            </div>
          </div>

          {pool.status !== 'GREEN' && (
            <div
              className="p-3 rounded-lg font-mono text-xs"
              style={{ background: 'rgba(244,63,94,0.06)', border: '1px solid rgba(244,63,94,0.2)' }}
            >
              <div className="text-rose-400 mb-1">
                ⚠ Interview trap: Aurora Serverless v2 does NOT increase max_connections!
              </div>
              <div className="text-slate-400">
                Serverless v2 scales ACU (compute units) — NOT connections.
                max_connections is based on instance memory formula, not load.
                At {replicas} replicas: {pool.total} connections {pool.total > AURORA_MAX ? `EXCEEDS Aurora max (${AURORA_MAX})` : `approaching limit`}.
              </div>
              <div className="text-slate-500 mt-2">
                Mitigations: RDS Proxy · reduce pool_size to 5 · pgBouncer · reduce num_services
              </div>
            </div>
          )}
        </div>
      </div>

      {/* ── Security Hub + ArgoCD ─────────────────────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="card-dark p-5">
          <div className="flex items-center gap-2 mb-4">
            <Shield className="w-4 h-4 text-emerald-400" />
            <h2 className="font-display font-semibold text-slate-200">Security Hub</h2>
          </div>
          {[
            { label: 'IAM / IRSA',        score: 95, color: '#10B981' },
            { label: 'Encryption',         score: 88, color: '#10B981' },
            { label: 'Network Policies',   score: 72, color: '#F59E0B' },
            { label: 'Pod Security (PSA)', score: 84, color: '#00D4FF' },
            { label: 'Overall CIS v1.4',  score: 84, color: '#10B981' },
          ].map((item) => (
            <div key={item.label} className="mb-3">
              <div className="flex justify-between font-mono text-xs mb-1">
                <span className="text-slate-400">{item.label}</span>
                <span style={{ color: item.color }}>{item.score}%</span>
              </div>
              <div className="w-full h-1.5 rounded-full" style={{ background: 'var(--bg-elevated)' }}>
                <div
                  className="h-full rounded-full transition-all duration-700"
                  style={{ width: `${item.score}%`, background: item.color }}
                />
              </div>
            </div>
          ))}
          <div className="mt-3 font-mono text-xs text-slate-500">
            Before remediation: 62% → After: 84% (+22 findings fixed)
          </div>
        </div>

        <div className="card-dark p-5">
          <div className="flex items-center gap-2 mb-4">
            <GitBranch className="w-4 h-4 text-cyan-400" />
            <h2 className="font-display font-semibold text-slate-200">ArgoCD GitOps</h2>
          </div>
          {[
            { app: 'compose-portal-prod', commit: 'a3f8c2d', ago: '14m' },
            { app: 'compose-portal-dev',  commit: 'a3f8c2d', ago: '14m' },
          ].map((app) => (
            <div
              key={app.app}
              className="p-3.5 rounded-lg mb-3"
              style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)' }}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="font-mono text-xs text-slate-300">{app.app}</span>
                <span className="status-running font-mono text-xs px-2 py-0.5 rounded-full">SYNCED</span>
              </div>
              <div className="flex gap-4 font-mono text-xs text-slate-500">
                <span>commit: <span className="text-cyan-400">{app.commit}</span></span>
                <span>synced {app.ago} ago</span>
                <span className="text-emerald-400">Healthy</span>
              </div>
            </div>
          ))}
          <div className="font-mono text-xs text-slate-500">
            selfHeal:true · prune:true · Self-heals in 52s after kubectl manual changes
            <br />GitOps rollback = git revert + push (no AWS API call needed)
          </div>
        </div>
      </div>
    </div>
  )
}
