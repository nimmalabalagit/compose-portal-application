import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { orderApi } from '../api/orderApi';
import { userApi } from '../api/userApi';
import type { OrderStatus } from '../api/types';
import toast from 'react-hot-toast';

// MATCHES BACKEND STATE MACHINE EXACTLY:
// PENDING → PROCESSING or CANCELLED
// PROCESSING → COMPLETED or CANCELLED
// COMPLETED, CANCELLED, DELIVERED, SHIPPED → terminal (no buttons)
const STATUS_CONFIG: Record<OrderStatus, { color: string; next: OrderStatus[] }> = {
  PENDING:    { color: 'bg-yellow-900/40 text-yellow-300 border-yellow-700',  next: ['PROCESSING', 'CANCELLED'] },
  PROCESSING: { color: 'bg-blue-900/40 text-blue-300 border-blue-700',        next: ['COMPLETED', 'CANCELLED'] },
  SHIPPED:    { color: 'bg-purple-900/40 text-purple-300 border-purple-700',  next: [] },
  DELIVERED:  { color: 'bg-green-900/40 text-green-300 border-green-700',     next: [] },
  CANCELLED:  { color: 'bg-red-900/40 text-red-300 border-red-700',           next: [] },
  COMPLETED:  { color: 'bg-emerald-900/40 text-emerald-300 border-emerald-700', next: [] },
};

const NEXT_BTN_COLORS: Record<string, string> = {
  PROCESSING: '#3b82f6',
  COMPLETED:  '#10B981',
  CANCELLED:  '#ef4444',
};

function formatPrice(amount: number): string {
  if (amount >= 10000000) return `₹${(amount / 10000000).toFixed(1)}Cr`;
  if (amount >= 100000)   return `₹${(amount / 100000).toFixed(0)}L`;
  return `₹${amount.toLocaleString()}`;
}

export default function OrdersPage() {
  const qc = useQueryClient();

  const { data: orders = [], isLoading } = useQuery({
    queryKey: ['orders'],
    queryFn: () => orderApi.getAll(),
    refetchInterval: 15_000,
  });

  const { data: users = [] } = useQuery({
    queryKey: ['users'],
    queryFn: () => userApi.getAll(),
  });

  const userMap = Object.fromEntries(users.map(u => [u.id, u]));

  const statusMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: OrderStatus }) =>
      orderApi.updateStatus(id, { status, changedBy: 'frontend-user' }),
    onSuccess: (updated) => {
      qc.invalidateQueries({ queryKey: ['orders'] });
      toast.success(`✅ Order ${updated.orderNumber} → ${updated.status}`);
    },
    onError: () => toast.error('❌ Status update failed'),
  });

  const statusGroups = {
    PENDING:    orders.filter(o => o.status === 'PENDING'),
    PROCESSING: orders.filter(o => o.status === 'PROCESSING'),
    COMPLETED:  orders.filter(o => o.status === 'COMPLETED'),
    CANCELLED:  orders.filter(o => o.status === 'CANCELLED'),
  };

  if (isLoading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-cyan-400 font-mono animate-pulse">Loading orders...</div>
    </div>
  );

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-slate-100">Orders</h1>
        <p className="text-sm text-slate-400 font-mono mt-0.5">
          {orders.length} total · PostgreSQL + MongoDB audit · RabbitMQ events
        </p>
      </div>

      {/* Stats Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {Object.entries(statusGroups).map(([status, list]) => (
          <div key={status}
            className="p-3 rounded-lg border border-slate-700 text-center"
            style={{ background: 'rgba(15,22,41,0.5)' }}
          >
            <div className="text-2xl font-bold font-mono text-slate-100">{list.length}</div>
            <div className={`text-xs font-mono mt-1 px-1.5 py-0.5 rounded border inline-block
              ${STATUS_CONFIG[status as OrderStatus]?.color}`}>
              {status}
            </div>
          </div>
        ))}
      </div>

      {/* Orders List */}
      <div className="space-y-3">
        {orders.map(order => {
          const buyer = userMap[order.buyerUserId];
          const config = STATUS_CONFIG[order.status];
          const nextStatuses = config?.next || [];

          return (
            <div key={order.id}
              className="p-4 rounded-lg border border-slate-700 hover:border-slate-600 transition-all"
              style={{ background: 'rgba(15,22,41,0.6)' }}
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-3 mb-2 flex-wrap">
                    <span className="font-mono text-sm font-semibold text-cyan-400">
                      {order.orderNumber}
                    </span>
                    <span className={`px-2 py-0.5 rounded text-xs border ${config?.color}`}>
                      {order.status}
                    </span>
                    <span className="font-mono text-sm font-bold text-green-400">
                      {formatPrice(order.amountTotal)}
                    </span>
                  </div>
                  <div className="text-xs font-mono text-slate-400 space-y-0.5">
                    {buyer && (
                      <div>
                        Buyer: <span className="text-slate-200">
                          {buyer.firstName} {buyer.lastName}
                        </span>
                        {' '}
                        <span className="text-slate-500">({buyer.email})</span>
                      </div>
                    )}
                    {order.notes && (
                      <div className="text-slate-500">{order.notes}</div>
                    )}
                    <div className="text-slate-600">
                      Created: {new Date(order.createdAt).toLocaleString()}
                    </div>
                  </div>
                </div>

                {nextStatuses.length > 0 && (
                  <div className="flex flex-col gap-2 flex-shrink-0">
                    {nextStatuses.map(next => (
                      <button
                        key={next}
                        onClick={() => statusMutation.mutate({ id: order.id, status: next })}
                        disabled={statusMutation.isPending}
                        className="px-3 py-1.5 rounded font-mono text-xs font-medium transition-all disabled:opacity-40 whitespace-nowrap"
                        style={{
                          background: `${NEXT_BTN_COLORS[next]}20`,
                          border: `1px solid ${NEXT_BTN_COLORS[next]}`,
                          color: NEXT_BTN_COLORS[next],
                        }}
                      >
                        → {next}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {orders.length === 0 && (
        <div className="text-center py-12 text-slate-500 font-mono">
          No orders yet — place an order from the Properties page
        </div>
      )}
    </div>
  );
}
