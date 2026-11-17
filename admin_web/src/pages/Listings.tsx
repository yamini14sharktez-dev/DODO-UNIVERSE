import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { ProductListing } from '../types';
import { DataTable, Column } from '../components/common/DataTable';
import { Badge } from '../components/common/Badge';
import { Check, X, Power, Truck } from 'lucide-react';

export const Listings: React.FC = () => {
  const [listings, setListings] = useState<ProductListing[]>([]);
  const [total, setTotal] = useState(0);
  const [statusFilter, setStatusFilter] = useState('');
  const [offset, setOffset] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  const fetchListings = async () => {
    setIsLoading(true);
    try {
      const res = await api.getListings(statusFilter, 20, offset);
      setListings(res.items || []);
      setTotal(res.total || 0);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchListings();
  }, [statusFilter, offset]);

  const handleApprove = async (id: string, status: 'approved' | 'rejected') => {
    try {
      await api.updateListingApproval(id, status);
      await fetchListings();
    } catch (err: any) {
      alert(err.message || 'Failed to update approval');
    }
  };

  const handleToggleActive = async (id: string, current: boolean) => {
    try {
      await api.updateListingStatus(id, !current);
      await fetchListings();
    } catch (err: any) {
      alert(err.message || 'Failed to update active state');
    }
  };

  const columns: Column<ProductListing>[] = [
    {
      header: 'Listing Title',
      accessor: 'title',
      render: (l) => (
        <div>
          <p className="font-bold text-slate-800">{l.title}</p>
          <p className="text-xs text-slate-400">
            {l.category_name || 'Category'} • Vendor: {l.vendor_name || 'Vendor'}
          </p>
        </div>
      ),
    },
    {
      header: 'Type',
      accessor: 'listing_type',
      render: (l) => <Badge status={l.listing_type} />,
    },
    {
      header: 'Pricing & Unit',
      render: (l) => (
        <div>
          <p className="font-bold text-slate-800">
            ₹{l.unit_price} / <span className="font-normal text-slate-500">{l.pricing_unit}</span>
          </p>
          <p className="text-[11px] text-slate-400">MOQ: {l.min_order_quantity} {l.pricing_unit}s</p>
        </div>
      ),
    },
    {
      header: 'Transportation',
      render: (l) =>
        l.has_transportation ? (
          <span className="inline-flex items-center gap-1 text-xs text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-full border border-emerald-200">
            <Truck className="w-3 h-3" />
            +₹{l.transportation_fee}
          </span>
        ) : (
          <span className="text-xs text-slate-400">No transport</span>
        ),
    },
    {
      header: 'Approval',
      render: (l) => <Badge status={l.approval_status} />,
    },
    {
      header: 'Active State',
      render: (l) => (
        <Badge
          status={l.is_active ? 'Active' : 'Inactive'}
          variant={l.is_active ? 'success' : 'neutral'}
        />
      ),
    },
    {
      header: 'Actions',
      className: 'text-right',
      render: (l) => (
        <div className="flex items-center justify-end gap-1.5">
          {l.approval_status === 'pending' && (
            <>
              <button
                onClick={() => handleApprove(l.id, 'approved')}
                className="p-1.5 text-emerald-600 hover:bg-emerald-50 rounded-lg transition"
                title="Approve Listing"
              >
                <Check className="w-4 h-4" />
              </button>
              <button
                onClick={() => handleApprove(l.id, 'rejected')}
                className="p-1.5 text-rose-600 hover:bg-rose-50 rounded-lg transition"
                title="Reject Listing"
              >
                <X className="w-4 h-4" />
              </button>
            </>
          )}
          <button
            onClick={() => handleToggleActive(l.id, l.is_active)}
            className={`p-1.5 rounded-lg transition ${
              l.is_active
                ? 'text-slate-400 hover:text-rose-600 hover:bg-rose-50'
                : 'text-slate-400 hover:text-emerald-600 hover:bg-emerald-50'
            }`}
            title={l.is_active ? 'Deactivate Listing' : 'Activate Listing'}
          >
            <Power className="w-4 h-4" />
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Products & Listings Configuration</h2>
          <p className="text-xs text-slate-500">
            Moderate vendor-submitted products, rate structures, MOQs, and transportation options.
          </p>
        </div>

        <div className="flex items-center gap-1 bg-white p-1 rounded-xl border border-slate-200 text-xs">
          {['', 'pending', 'approved', 'rejected'].map((st) => (
            <button
              key={st}
              onClick={() => {
                setStatusFilter(st);
                setOffset(0);
              }}
              className={`px-3 py-1.5 rounded-lg font-semibold capitalize transition ${
                statusFilter === st
                  ? 'bg-pine-700 text-white shadow-sm'
                  : 'text-slate-500 hover:text-slate-800 hover:bg-slate-50'
              }`}
            >
              {st === '' ? 'All Listings' : st}
            </button>
          ))}
        </div>
      </div>

      <DataTable
        columns={columns}
        data={listings}
        total={total}
        limit={20}
        offset={offset}
        onPageChange={setOffset}
        isLoading={isLoading}
        emptyTitle="No listings available"
        emptyDescription="When vendors create product or service listings, they will appear here for administrative approval."
      />
    </div>
  );
};
