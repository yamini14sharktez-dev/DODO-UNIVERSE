import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { PaymentRecord, CommissionRule } from '../types';
import { DataTable, Column } from '../components/common/DataTable';
import { Badge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { CreditCard, Percent, DollarSign, Plus } from 'lucide-react';

export const Payments: React.FC = () => {
  const [payments, setPayments] = useState<PaymentRecord[]>([]);
  const [commissions, setCommissions] = useState<CommissionRule[]>([]);
  const [total, setTotal] = useState(0);
  const [paymentTypeFilter, setPaymentTypeFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [offset, setOffset] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  // Commission modal
  const [isCommissionModalOpen, setIsCommissionModalOpen] = useState(false);
  const [percent, setPercent] = useState('10.0');
  const [fixedFee, setFixedFee] = useState('0.0');

  const fetchPayments = async () => {
    setIsLoading(true);
    try {
      const res = await api.getPayments(paymentTypeFilter, statusFilter, 20, offset);
      setPayments(res.items || []);
      setTotal(res.total || 0);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchCommissions = async () => {
    try {
      const rules = await api.getCommissionRules();
      setCommissions(rules || []);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchPayments();
    fetchCommissions();
  }, [paymentTypeFilter, statusFilter, offset]);

  const handleSaveCommission = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.setCommissionRule({
        commission_percent: parseFloat(percent) || 0,
        fixed_fee: parseFloat(fixedFee) || 0,
        is_active: true,
      });
      setIsCommissionModalOpen(false);
      await fetchCommissions();
    } catch (err: any) {
      alert(err.message || 'Failed to configure commission');
    }
  };

  const columns: Column<PaymentRecord>[] = [
    {
      header: 'Transaction ID',
      accessor: 'id',
      render: (p) => (
        <div>
          <p className="font-mono font-bold text-slate-800">#{p.id.slice(0, 8)}</p>
          <p className="text-[11px] text-slate-400 font-mono">{p.reference_number || 'Internal Transfer'}</p>
        </div>
      ),
    },
    {
      header: 'Payer / Account',
      accessor: 'payer_name',
      render: (p) => (
        <span className="font-semibold text-slate-800 text-xs">{p.payer_name || 'Account Holder'}</span>
      ),
    },
    {
      header: 'Type',
      accessor: 'payment_type',
      render: (p) => <Badge status={p.payment_type} />,
    },
    {
      header: 'Amount',
      render: (p) => (
        <span className="font-bold text-slate-800 text-sm">₹{p.amount.toLocaleString()}</span>
      ),
    },
    {
      header: 'Ledger Status',
      render: (p) => <Badge status={p.status} />,
    },
    {
      header: 'Date',
      render: (p) => (
        <span className="text-xs text-slate-500 font-mono">
          {new Date(p.created_at).toLocaleString()}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-8">
      {/* Platform Commission Rules Section */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-slate-100 pb-4">
          <div>
            <h3 className="text-sm font-bold text-slate-800">Platform Commission Configuration</h3>
            <p className="text-xs text-slate-400">
              Configured take rates applied automatically during order settlement and vendor payouts.
            </p>
          </div>
          <button
            onClick={() => setIsCommissionModalOpen(true)}
            className="px-3.5 py-2 bg-pine-700 hover:bg-pine-800 text-white rounded-xl text-xs font-bold transition flex items-center gap-1.5 shadow-sm"
          >
            <Plus className="w-3.5 h-3.5" />
            Set Commission Rule
          </button>
        </div>

        {commissions.length === 0 ? (
          <div className="py-6 text-center text-xs text-slate-400 border border-dashed rounded-xl">
            Default global commission rate: 10.0%
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {commissions.map((cr) => (
              <div key={cr.id} className="p-4 bg-slate-50 border border-slate-200 rounded-xl">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                  {cr.category_name || 'Global Rate'}
                </span>
                <div className="text-2xl font-black text-slate-800 mt-1">
                  {cr.commission_percent}%
                </div>
                <p className="text-[11px] text-slate-500 mt-0.5">+ Fixed Fee: ₹{cr.fixed_fee}</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Payment Ledger Section */}
      <div className="space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-lg font-bold text-slate-800">Financial Ledger & Payouts</h2>
            <p className="text-xs text-slate-500">
              Audit log of order customer payments, vendor payouts, and refund records.
            </p>
          </div>

          <div className="flex items-center gap-2">
            <select
              value={paymentTypeFilter}
              onChange={(e) => {
                setPaymentTypeFilter(e.target.value);
                setOffset(0);
              }}
              className="p-2 bg-white border border-slate-200 rounded-xl text-xs font-semibold text-slate-700"
            >
              <option value="">All Types</option>
              <option value="order_payment">Order Payments</option>
              <option value="vendor_payout">Vendor Payouts</option>
              <option value="refund">Refunds</option>
            </select>
          </div>
        </div>

        <DataTable
          columns={columns}
          data={payments}
          total={total}
          limit={20}
          offset={offset}
          onPageChange={setOffset}
          isLoading={isLoading}
          emptyTitle="No financial records found yet"
          emptyDescription="Order payments, refunds, and vendor payout distributions will be recorded here."
        />
      </div>

      {/* Commission Modal */}
      <Modal
        isOpen={isCommissionModalOpen}
        onClose={() => setIsCommissionModalOpen(false)}
        title="Configure Platform Commission Rule"
        maxWidth="md"
      >
        <form onSubmit={handleSaveCommission} className="space-y-4 text-xs">
          <div>
            <label className="block font-bold text-slate-700 mb-1">Commission Percentage (%)</label>
            <input
              type="number"
              step="0.1"
              required
              value={percent}
              onChange={(e) => setPercent(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Fixed Flat Fee (₹)</label>
            <input
              type="number"
              step="1"
              value={fixedFee}
              onChange={(e) => setFixedFee(e.target.value)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
            />
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
            <button
              type="button"
              onClick={() => setIsCommissionModalOpen(false)}
              className="px-4 py-2 border border-slate-200 rounded-xl font-semibold text-slate-600 hover:bg-slate-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-5 py-2 bg-pine-700 hover:bg-pine-800 text-white rounded-xl font-bold transition shadow-sm"
            >
              Save Rule
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
};
