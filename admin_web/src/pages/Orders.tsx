import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { AdminOrder } from '../types';
import { DataTable, Column } from '../components/common/DataTable';
import { Badge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { Eye, AlertTriangle, ShieldCheck } from 'lucide-react';

export const Orders: React.FC = () => {
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [total, setTotal] = useState(0);
  const [statusFilter, setStatusFilter] = useState('');
  const [search, setSearch] = useState('');
  const [offset, setOffset] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  // Selected Order Modal
  const [selectedOrder, setSelectedOrder] = useState<AdminOrder | null>(null);
  const [disputeNotes, setDisputeNotes] = useState('');
  const [isResolving, setIsResolving] = useState(false);

  const fetchOrders = async (st = statusFilter, q = search, off = offset) => {
    setIsLoading(true);
    try {
      const res = await api.getOrders(st, q, 20, off);
      setOrders(res.items || []);
      setTotal(res.total || 0);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchOrders();
  }, [statusFilter, offset]);

  const handleSearch = (val: string) => {
    setSearch(val);
    setOffset(0);
    fetchOrders(statusFilter, val, 0);
  };

  const handleResolveDispute = async () => {
    if (!selectedOrder || !disputeNotes.trim()) return;
    setIsResolving(true);
    try {
      await api.resolveOrderDispute(selectedOrder.id, disputeNotes);
      setSelectedOrder(null);
      setDisputeNotes('');
      await fetchOrders();
    } catch (err: any) {
      alert(err.message || 'Failed to resolve dispute');
    } finally {
      setIsResolving(false);
    }
  };

  const columns: Column<AdminOrder>[] = [
    {
      header: 'Order Reference',
      accessor: 'id',
      render: (o) => (
        <div>
          <p className="font-bold text-slate-800 font-mono">#{o.id.slice(0, 8)}</p>
          <p className="text-[11px] text-slate-400">{new Date(o.created_at).toLocaleString()}</p>
        </div>
      ),
    },
    {
      header: 'Customer',
      render: (o) => (
        <div>
          <p className="font-semibold text-slate-800">{o.customer_name || 'Customer'}</p>
          <p className="text-[11px] text-slate-400 font-mono">{o.customer_phone}</p>
        </div>
      ),
    },
    {
      header: 'Vendor',
      render: (o) => (
        <div>
          <p className="font-semibold text-slate-800">{o.vendor_name || 'Vendor'}</p>
          <p className="text-[11px] text-slate-400 font-mono">{o.vendor_phone}</p>
        </div>
      ),
    },
    {
      header: 'Total Amount',
      render: (o) => (
        <div>
          <p className="font-bold text-slate-800">₹{o.total_amount.toLocaleString()}</p>
          <p className="text-[10px] text-slate-400">Commission: ₹{o.commission_amount}</p>
        </div>
      ),
    },
    {
      header: 'Order Status',
      render: (o) => <Badge status={o.status} />,
    },
    {
      header: 'Actions',
      className: 'text-right',
      render: (o) => (
        <button
          onClick={() => setSelectedOrder(o)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-pine-700 bg-pine-50 hover:bg-pine-100 transition"
        >
          <Eye className="w-3.5 h-3.5" />
          View Details
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Bookings & Orders Oversight</h2>
          <p className="text-xs text-slate-500">
            Administrative monitoring screen for tracking lifecycle progress, customer-vendor fulfillment, and disputes.
          </p>
        </div>

        {/* Status Filter Tabs */}
        <div className="flex items-center gap-1 bg-white p-1 rounded-xl border border-slate-200 text-xs overflow-x-auto">
          {['', 'pending', 'vendor_accepted', 'in_progress', 'completed', 'cancelled', 'disputed'].map(
            (st) => (
              <button
                key={st}
                onClick={() => {
                  setStatusFilter(st);
                  setOffset(0);
                }}
                className={`px-3 py-1.5 rounded-lg font-semibold capitalize whitespace-nowrap transition ${
                  statusFilter === st
                    ? 'bg-pine-700 text-white shadow-sm'
                    : 'text-slate-500 hover:text-slate-800 hover:bg-slate-50'
                }`}
              >
                {st === '' ? 'All Orders' : st.replace(/_/g, ' ')}
              </button>
            )
          )}
        </div>
      </div>

      <DataTable
        columns={columns}
        data={orders}
        total={total}
        limit={20}
        offset={offset}
        onPageChange={setOffset}
        searchValue={search}
        onSearchChange={handleSearch}
        searchPlaceholder="Search by customer name, vendor name, or phone..."
        isLoading={isLoading}
        emptyTitle="No orders found yet"
        emptyDescription="Customer bookings and orders placed across the platform will appear here in real-time."
      />

      {/* Order Details & Dispute Modal */}
      <Modal
        isOpen={!!selectedOrder}
        onClose={() => {
          setSelectedOrder(null);
          setDisputeNotes('');
        }}
        title={`Order Details: #${selectedOrder?.id.slice(0, 8)}`}
        maxWidth="lg"
      >
        {selectedOrder && (
          <div className="space-y-6 text-xs">
            {/* Status Header */}
            <div className="p-4 bg-slate-50 border border-slate-200 rounded-xl flex items-center justify-between">
              <div>
                <p className="font-bold text-slate-800 text-sm">
                  ₹{selectedOrder.total_amount.toLocaleString()}
                </p>
                <p className="text-slate-400">Platform Commission: ₹{selectedOrder.commission_amount}</p>
              </div>
              <Badge status={selectedOrder.status} />
            </div>

            {/* Parties */}
            <div className="grid grid-cols-2 gap-4">
              <div className="p-3 bg-white border border-slate-200 rounded-xl">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                  Customer
                </span>
                <p className="font-bold text-slate-800 mt-1">{selectedOrder.customer_name || 'Customer'}</p>
                <p className="text-slate-500 font-mono mt-0.5">{selectedOrder.customer_phone}</p>
              </div>
              <div className="p-3 bg-white border border-slate-200 rounded-xl">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                  Vendor
                </span>
                <p className="font-bold text-slate-800 mt-1">{selectedOrder.vendor_name || 'Vendor'}</p>
                <p className="text-slate-500 font-mono mt-0.5">{selectedOrder.vendor_phone}</p>
              </div>
            </div>

            {/* Itemized Order Details */}
            <div>
              <h4 className="font-bold text-slate-700 uppercase tracking-wider mb-2">
                Order Specification
              </h4>
              <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 font-mono text-[11px] max-h-40 overflow-y-auto">
                <pre>{JSON.stringify(selectedOrder.order_details, null, 2)}</pre>
              </div>
            </div>

            {/* Dispute Resolution Section */}
            {selectedOrder.status === 'disputed' && (
              <div className="p-4 bg-rose-50 border border-rose-200 rounded-xl space-y-3">
                <div className="flex items-center gap-2 text-rose-800 font-bold">
                  <AlertTriangle className="w-4 h-4" />
                  <span>Order is Marked as Disputed</span>
                </div>
                <p className="text-rose-700">
                  Reason: {selectedOrder.dispute_reason || 'Customer or vendor lodged a dispute.'}
                </p>
                <textarea
                  value={disputeNotes}
                  onChange={(e) => setDisputeNotes(e.target.value)}
                  placeholder="Enter administrative dispute resolution notes..."
                  rows={2}
                  className="w-full p-2.5 bg-white border border-rose-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-rose-500/20"
                />
                <button
                  onClick={handleResolveDispute}
                  disabled={isResolving}
                  className="px-4 py-2 bg-rose-700 hover:bg-rose-800 text-white rounded-xl font-bold flex items-center gap-1.5"
                >
                  <ShieldCheck className="w-4 h-4" />
                  Resolve and Complete Order
                </button>
              </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
};
