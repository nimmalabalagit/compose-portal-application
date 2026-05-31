import { useQuery } from '@tanstack/react-query'
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts'
import { Users, Package, ShoppingCart, TrendingUp, Activity, CheckCircle2 } from 'lucide-react'
import { userApi } from '../api/userApi'
import { productApi } from '../api/productApi'
import { orderApi } from '../api/orderApi'

// Mock 30-day revenue trend (replace with real time-series API in production)
const revenueData = Array.from({ length: 30 }, (_, i) => ({
  day: `${i + 1}`,
  revenue: Math.floor(Math.random() * 8000000) + 2000000,
}))

const SERVICES = [
  { name: 'gateway-service', port: 8080, color: '#00D4FF' },
  { name: 'user-service',    port: 8081, color: '#10B981' },
  { name: 'product-service', port: 8082, color: '#F59E0B' },
  { name: 'order-service',   port: 8083, color: '#818CF8' },
]

function MetricCard({
  icon: Icon, label, value, sub, color = '#00D4FF',
}: {
  icon: React.ElementType
  label: string
  value: string | number
  sub?: string
  color?: string
}) {
  return (
    <div className="card-dark p-5 relative overflow-hidden">
      <div
        className="absolute top-0 right-0 w-32 h-32 rounded-full opacity-5"
        style={{ background: color, transform: 'translate(40%,-40%)' }}
      />
      <div className="flex items-start justify-between mb-4">
        <div
          className="p-2 rounded-lg"
          style={{ background: `${color}15`, border: `1px solid ${color}25` }}
        >
          <Icon className="w-4 h-4" style={{ color }} />
        </div>
      </div>
      <div className="metric-number text-3xl font-bold mb-1" style={{ color }}>
        {value}
      </div>
      <div className="text-xs font-medium text-slate-400 uppercase tracking-wider">{label}</div>
      {sub && <div className="text-xs text-slate-600 mt-0.5 font-mono">{sub}</div>}
    </div>
  )
}

export default function Dashboard() {
  const { data: users = [] } = useQuery({
    queryKey: ['users'],
    queryFn: () => userApi.getAll(),
    staleTime: 30_000,
  })

  const { data: products = [] } = useQuery({
    queryKey: ['products'],
    queryFn: () => productApi.getAll(),
    staleTime: 5 * 60_000,
  })

  const { data: orders = [] } = useQuery({
    queryKey: ['orders'],
    queryFn: () => orderApi.getAll(),
    staleTime: 10_000,
  })

  const totalRevenue = orders
    .filter((o) => o.status === 'COMPLETED')
    .reduce((s, o) => s + o.amountTotal, 0)

  const activeListings = products.filter((p) => p.status === 'AVAILABLE').length
  const pendingOrders  = orders.filter((o) => o.status === 'PENDING').length
  const activeUsers    = users.filter((u) => u.active).length

  return (
    <div className="space-y-6">

      {/* Header */}
      <div>
        <h1 className="font-display text-2xl font-bold text-slate-100">Command Center</h1>
        <p className="text-sm text-slate-500 font-mono mt-0.5">
          EKS compose-portal-eks v1.32 · Karpenter v0.37 · ArgoCD GitOps
        </p>
      </div>

      {/* Metric cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard
          icon={Package}
          label="Active Listings"
          value={activeListings}
          sub="PostgreSQL + Redis 5min TTL"
          color="#00D4FF"
        />
        <MetricCard
          icon={ShoppingCart}
          label="Pending Orders"
          value={pendingOrders}
          sub="MongoDB audit trail"
          color="#F59E0B"
        />
        <MetricCard
          icon={Users}
          label="Active Users"
          value={activeUsers}
          sub="BCrypt + IRSA zero-creds"
          color="#10B981"
        />
        <MetricCard
          icon={TrendingUp}
          label="Revenue (Completed)"
          value={`₹${(totalRevenue / 1_00_00_000).toFixed(1)}Cr`}
          sub="NUMERIC(12,2) — exact decimal"
          color="#818CF8"
        />
      </div>

      {/* Revenue chart + Service health */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">

        <div className="card-dark p-5 lg:col-span-2">
          <div className="flex items-center justify-between mb-5">
            <h2 className="font-display font-semibold text-slate-200">Revenue — Last 30 Days</h2>
            <span className="font-mono text-xs text-slate-500">Recharts → /api/orders</span>
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={revenueData}>
              <defs>
                <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor="#00D4FF" stopOpacity={0.15} />
                  <stop offset="95%" stopColor="#00D4FF" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis
                dataKey="day"
                tick={{ fill: '#4B5563', fontSize: 10, fontFamily: 'JetBrains Mono' }}
                tickLine={false}
                axisLine={{ stroke: 'rgba(255,255,255,0.06)' }}
                interval={4}
              />
              <YAxis
                tick={{ fill: '#4B5563', fontSize: 10, fontFamily: 'JetBrains Mono' }}
                tickLine={false}
                axisLine={false}
                tickFormatter={(v: number) => `₹${(v / 100000).toFixed(0)}L`}
              />
              <Tooltip
                contentStyle={{
                  background: 'var(--bg-elevated)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: '8px',
                  color: 'var(--text-primary)',
                  fontFamily: 'JetBrains Mono',
                  fontSize: '12px',
                }}
                formatter={(v: number) => [`₹${(v / 100000).toFixed(1)}L`, 'Revenue']}
              />
              <Area type="monotone" dataKey="revenue" stroke="#00D4FF" strokeWidth={2} fill="url(#revGrad)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="card-dark p-5">
          <div className="flex items-center gap-2 mb-4">
            <Activity className="w-4 h-4 text-cyan-400" />
            <h2 className="font-display font-semibold text-slate-200">Service Health</h2>
          </div>
          <div className="space-y-3">
            {SERVICES.map((svc) => (
              <div key={svc.name} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full animate-pulse-slow" style={{ background: svc.color }} />
                  <span className="font-mono text-xs text-slate-300">{svc.name}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs text-slate-500">:{svc.port}</span>
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                </div>
              </div>
            ))}
          </div>
          <div className="mt-4 pt-4 border-t border-slate-700">
            <div className="font-mono text-xs text-slate-500 mb-2">HikariCP Pool Math</div>
            <div className="space-y-1">
              {['users_db:5432', 'products_db:5433', 'orders_db:5434'].map((db) => (
                <div key={db} className="flex justify-between font-mono text-xs">
                  <span className="text-slate-500">{db}</span>
                  <span style={{ color: '#10B981' }}>pool=10 ✓</span>
                </div>
              ))}
            </div>
            <div className="mt-2 font-mono text-xs text-slate-600">
              34 max replicas/svc · floor(1708×0.8/4/10)
            </div>
          </div>
        </div>
      </div>

      {/* Recent transactions */}
      <div className="card-dark p-5">
        <h2 className="font-display font-semibold text-slate-200 mb-4">Recent Transactions</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-700">
                {['Order #', 'Status', 'Amount', 'Created'].map((h) => (
                  <th key={h} className="text-left font-mono text-xs text-slate-500 py-2 pr-6 uppercase">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {orders.slice(0, 6).map((order) => (
                <tr key={order.id} className="border-b border-slate-800 hover:bg-slate-800/40">
                  <td className="py-2.5 pr-6 font-mono text-xs text-cyan-400">
                    {order.orderNumber || order.id.slice(0, 8).toUpperCase()}
                  </td>
                  <td className="py-2.5 pr-6">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-mono
                      ${order.status === 'COMPLETED'  ? 'status-completed' :
                        order.status === 'PENDING'    ? 'status-pending' :
                        order.status === 'PROCESSING' ? 'status-running' : 'status-cancelled'}`}>
                      {order.status}
                    </span>
                  </td>
                  <td className="py-2.5 pr-6 font-mono text-xs text-slate-300">
                    ₹{(order.amountTotal / 100000).toFixed(1)}L
                  </td>
                  <td className="py-2.5 font-mono text-xs text-slate-500">
                    {new Date(order.createdAt).toLocaleDateString('en-IN')}
                  </td>
                </tr>
              ))}
              {orders.length === 0 && (
                <tr>
                  <td colSpan={4} className="py-8 text-center font-mono text-xs text-slate-600">
                    No orders — is docker-compose up?
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
