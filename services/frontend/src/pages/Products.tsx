import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { productApi } from '../api/productApi';
import { orderApi } from '../api/orderApi';
import { userApi } from '../api/userApi';
import type { Product, CreateOrderRequest } from '../api/types';
import toast from 'react-hot-toast';

const TYPE_COLORS: Record<string, string> = {
  APARTMENT:  'bg-blue-900/40 text-blue-300 border-blue-700',
  VILLA:      'bg-purple-900/40 text-purple-300 border-purple-700',
  PLOT:       'bg-yellow-900/40 text-yellow-300 border-yellow-700',
  COMMERCIAL: 'bg-orange-900/40 text-orange-300 border-orange-700',
  PENTHOUSE:  'bg-pink-900/40 text-pink-300 border-pink-700',
  STUDIO:     'bg-cyan-900/40 text-cyan-300 border-cyan-700',
};

const STATUS_COLORS: Record<string, string> = {
  AVAILABLE:        'bg-green-900/40 text-green-300 border-green-700',
  SOLD:             'bg-red-900/40 text-red-300 border-red-700',
  RESERVED:         'bg-yellow-900/40 text-yellow-300 border-yellow-700',
  PENDING_APPROVAL: 'bg-slate-700/40 text-slate-300 border-slate-600',
};

function formatPrice(amount: number): string {
  if (amount >= 10000000) return `₹${(amount / 10000000).toFixed(1)}Cr`;
  if (amount >= 100000)   return `₹${(amount / 100000).toFixed(0)}L`;
  return `₹${amount.toLocaleString()}`;
}

export default function ProductsPage() {
  const qc = useQueryClient();
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [selectedBuyerId, setSelectedBuyerId] = useState('');
  const [orderNotes, setOrderNotes] = useState('');

  const { data: products = [], isLoading } = useQuery({
    queryKey: ['products'],
    queryFn: () => productApi.getAll(),
    refetchInterval: 30_000,
  });

  const { data: users = [] } = useQuery({
    queryKey: ['users'],
    queryFn: () => userApi.getAll(),
  });

  const buyers = users.filter(u => u.role === 'BUYER' || u.role === 'AGENT');

  const orderMutation = useMutation({
    mutationFn: (req: CreateOrderRequest) => orderApi.create(req),
    onSuccess: (order) => {
      qc.invalidateQueries({ queryKey: ['orders'] });
      toast.success(`🎉 Order ${order.orderNumber} placed! Amount: ${formatPrice(order.amountTotal)}`);
      setSelectedProduct(null);
      setSelectedBuyerId('');
      setOrderNotes('');
    },
    onError: () => toast.error('❌ Order failed — check order service logs'),
  });

  const handlePlaceOrder = () => {
    if (!selectedProduct || !selectedBuyerId) {
      toast.error('Select a buyer to continue');
      return;
    }
    orderMutation.mutate({
      buyerUserId: selectedBuyerId,
      productId: selectedProduct.id,
      amountTotal: selectedProduct.priceAmount,
      currency: selectedProduct.priceCurrency || 'INR',
      notes: orderNotes || `Order for ${selectedProduct.title}`,
    });
  };

  if (isLoading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-cyan-400 font-mono animate-pulse">Loading properties...</div>
    </div>
  );

  return (
    <div>
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-slate-100">Properties</h1>
        <p className="text-sm text-slate-400 font-mono mt-0.5">
          {products.filter(p => p.status === 'AVAILABLE').length} available ·{' '}
          {products.length} total · Redis cache active
        </p>
      </div>

      {/* Place Order Modal */}
      {selectedProduct && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70">
          <div className="w-full max-w-md p-6 rounded-xl border border-cyan-700/50 bg-slate-900 shadow-2xl">
            <h2 className="text-base font-mono text-cyan-400 mb-1">PLACE ORDER</h2>
            <p className="text-sm text-slate-300 mb-4">{selectedProduct.title}</p>

            <div className="space-y-3">
              <div className="p-3 rounded bg-slate-800 border border-slate-700">
                <div className="flex justify-between text-sm font-mono">
                  <span className="text-slate-400">Amount</span>
                  <span className="text-green-400 font-semibold">
                    {formatPrice(selectedProduct.priceAmount)}
                  </span>
                </div>
                <div className="flex justify-between text-sm font-mono mt-1">
                  <span className="text-slate-400">Location</span>
                  <span className="text-slate-300">{selectedProduct.location}</span>
                </div>
                <div className="flex justify-between text-sm font-mono mt-1">
                  <span className="text-slate-400">Type</span>
                  <span className="text-slate-300">{selectedProduct.propertyType}</span>
                </div>
              </div>

              <div>
                <label className="text-xs font-mono text-slate-400 mb-1 block">
                  Select Buyer *
                </label>
                <select
                  className="w-full bg-slate-800 border border-slate-600 rounded px-3 py-2 text-sm text-slate-100 font-mono focus:border-cyan-500 outline-none"
                  value={selectedBuyerId}
                  onChange={e => setSelectedBuyerId(e.target.value)}
                >
                  <option value="">-- Select buyer --</option>
                  {buyers.map(u => (
                    <option key={u.id} value={u.id}>
                      {u.firstName} {u.lastName} ({u.email})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-mono text-slate-400 mb-1 block">
                  Notes (optional)
                </label>
                <input
                  className="w-full bg-slate-800 border border-slate-600 rounded px-3 py-2 text-sm text-slate-100 font-mono focus:border-cyan-500 outline-none"
                  value={orderNotes}
                  onChange={e => setOrderNotes(e.target.value)}
                  placeholder="Any special requirements..."
                />
              </div>
            </div>

            <div className="flex gap-3 mt-5">
              <button
                onClick={() => setSelectedProduct(null)}
                className="flex-1 py-2 rounded font-mono text-sm border border-slate-600 text-slate-400 hover:border-slate-500 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handlePlaceOrder}
                disabled={!selectedBuyerId || orderMutation.isPending}
                className="flex-1 py-2 rounded font-mono text-sm font-medium transition-all disabled:opacity-40"
                style={{ background: '#10B981', color: '#0a0f1e' }}
              >
                {orderMutation.isPending ? 'Placing...' : `Confirm Order →`}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Property Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {products.map(product => (
          <div
            key={product.id}
            className="rounded-lg border border-slate-700 overflow-hidden hover:border-slate-500 transition-all"
            style={{ background: 'rgba(15,22,41,0.7)' }}
          >
            {/* Card Header */}
            <div className="p-4 border-b border-slate-700/50">
              <div className="flex items-start justify-between gap-2 mb-2">
                <h3 className="text-sm font-semibold text-slate-100 leading-tight">
                  {product.title}
                </h3>
                <span className={`px-2 py-0.5 rounded text-xs border flex-shrink-0 ${STATUS_COLORS[product.status]}`}>
                  {product.status}
                </span>
              </div>
              <p className="text-xs text-slate-500 font-mono">{product.location}</p>
            </div>

            {/* Card Body */}
            <div className="p-4 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-2xl font-bold text-green-400 font-mono">
                  {formatPrice(product.priceAmount)}
                </span>
                <span className={`px-2 py-0.5 rounded text-xs border ${TYPE_COLORS[product.propertyType] || TYPE_COLORS.APARTMENT}`}>
                  {product.propertyType}
                </span>
              </div>

              <div className="grid grid-cols-3 gap-2 text-xs font-mono text-slate-400">
                <div className="text-center p-2 rounded bg-slate-800/50">
                  <div className="text-slate-200 font-medium">{product.bedrooms}</div>
                  <div>BHK</div>
                </div>
                <div className="text-center p-2 rounded bg-slate-800/50">
                  <div className="text-slate-200 font-medium">{product.bathrooms}</div>
                  <div>Bath</div>
                </div>
                <div className="text-center p-2 rounded bg-slate-800/50">
                  <div className="text-slate-200 font-medium">{product.areaSqft}</div>
                  <div>sqft</div>
                </div>
              </div>

              <p className="text-xs text-slate-500 line-clamp-2">{product.description}</p>
            </div>

            {/* Card Footer */}
            <div className="px-4 pb-4">
              <button
                onClick={() => product.status === 'AVAILABLE' && setSelectedProduct(product)}
                disabled={product.status !== 'AVAILABLE'}
                className="w-full py-2 rounded font-mono text-sm font-medium transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                style={{
                  background: product.status === 'AVAILABLE' ? 'rgba(16,185,129,0.15)' : 'transparent',
                  border: `1px solid ${product.status === 'AVAILABLE' ? '#10B981' : '#374151'}`,
                  color: product.status === 'AVAILABLE' ? '#10B981' : '#6b7280',
                }}
              >
                {product.status === 'AVAILABLE' ? '🏠 Buy Now' : product.status}
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
