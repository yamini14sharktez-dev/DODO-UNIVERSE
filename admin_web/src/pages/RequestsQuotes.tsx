import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { QuotationRequest } from '../types';
import { DataTable, Column } from '../components/common/DataTable';
import { Badge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { Eye, MessageSquareReply, Tag } from 'lucide-react';

export const RequestsQuotes: React.FC = () => {
  const [requests, setRequests] = useState<QuotationRequest[]>([]);
  const [total, setTotal] = useState(0);
  const [statusFilter, setStatusFilter] = useState('');
  const [offset, setOffset] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  const [selectedRequest, setSelectedRequest] = useState<QuotationRequest | null>(null);

  const fetchRequests = async () => {
    setIsLoading(true);
    try {
      const res = await api.getQuotationRequests(statusFilter, 20, offset);
      setRequests(res.items || []);
      setTotal(res.total || 0);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchRequests();
  }, [statusFilter, offset]);

  const openDetails = async (req: QuotationRequest) => {
    setSelectedRequest(req);
    try {
      const full = await api.getQuotationRequest(req.id);
      setSelectedRequest(full);
    } catch (err) {
      console.error(err);
    }
  };

  const columns: Column<QuotationRequest>[] = [
    {
      header: 'Request Title',
      accessor: 'title',
      render: (r) => (
        <div>
          <p className="font-bold text-slate-800">{r.title}</p>
          <p className="text-xs text-slate-400">
            {r.category_name || 'General Category'} • #{r.id.slice(0, 8)}
          </p>
        </div>
      ),
    },
    {
      header: 'Customer',
      accessor: 'customer_name',
      render: (r) => (
        <span className="font-semibold text-slate-800 text-xs">{r.customer_name || 'Customer'}</span>
      ),
    },
    {
      header: 'Bids Received',
      render: (r) => (
        <span className="inline-flex items-center gap-1 text-xs font-bold text-pine-800 bg-pine-50 px-2.5 py-1 rounded-full border border-pine-200">
          <Tag className="w-3 h-3 text-pine-600" />
          {r.quotations ? r.quotations.length : 0} Quotations
        </span>
      ),
    },
    {
      header: 'Status',
      render: (r) => <Badge status={r.status} />,
    },
    {
      header: 'Created Date',
      render: (r) => (
        <span className="text-xs text-slate-500 font-mono">
          {new Date(r.created_at).toLocaleDateString()}
        </span>
      ),
    },
    {
      header: 'Actions',
      className: 'text-right',
      render: (r) => (
        <button
          onClick={() => openDetails(r)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-pine-700 bg-pine-50 hover:bg-pine-100 transition"
        >
          <Eye className="w-3.5 h-3.5" />
          Inspect RFQ
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Requests & Quotations Oversight</h2>
          <p className="text-xs text-slate-500">
            Monitor custom requests for quotation (RFQs), incoming vendor price bids, and response velocity.
          </p>
        </div>

        <div className="flex items-center gap-1 bg-white p-1 rounded-xl border border-slate-200 text-xs">
          {['', 'open', 'responded', 'closed', 'cancelled'].map((st) => (
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
              {st === '' ? 'All Requests' : st}
            </button>
          ))}
        </div>
      </div>

      <DataTable
        columns={columns}
        data={requests}
        total={total}
        limit={20}
        offset={offset}
        onPageChange={setOffset}
        isLoading={isLoading}
        emptyTitle="No quotation requests found yet"
        emptyDescription="Customer custom quotation requests and vendor bids will appear here."
      />

      {/* RFQ & Bids Modal */}
      <Modal
        isOpen={!!selectedRequest}
        onClose={() => setSelectedRequest(null)}
        title={`RFQ: ${selectedRequest?.title}`}
        maxWidth="xl"
      >
        {selectedRequest && (
          <div className="space-y-6 text-xs">
            <div className="p-4 bg-slate-50 border border-slate-200 rounded-xl flex items-center justify-between">
              <div>
                <p className="font-bold text-slate-800 text-sm">{selectedRequest.title}</p>
                <p className="text-slate-400">Customer: {selectedRequest.customer_name}</p>
              </div>
              <Badge status={selectedRequest.status} />
            </div>

            <div>
              <h4 className="font-bold text-slate-700 uppercase tracking-wider mb-2">
                Specification Details
              </h4>
              <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 font-mono text-[11px] max-h-40 overflow-y-auto">
                <pre>{JSON.stringify(selectedRequest.details, null, 2)}</pre>
              </div>
            </div>

            <div>
              <h4 className="font-bold text-slate-700 uppercase tracking-wider mb-2">
                Vendor Quotations & Bids ({selectedRequest.quotations?.length || 0})
              </h4>
              {!selectedRequest.quotations || selectedRequest.quotations.length === 0 ? (
                <p className="text-xs text-slate-400 py-6 text-center border border-dashed rounded-xl">
                  No vendor quotations submitted yet for this request.
                </p>
              ) : (
                <div className="space-y-2">
                  {selectedRequest.quotations.map((q) => (
                    <div key={q.id} className="p-3 bg-white border border-slate-200 rounded-xl flex items-center justify-between">
                      <div>
                        <p className="font-bold text-slate-800">{q.vendor_name || 'Vendor'}</p>
                        <p className="text-slate-400 text-[11px]">{q.notes || 'No bid notes attached'}</p>
                      </div>
                      <div className="text-right">
                        <p className="font-bold text-slate-800 text-sm">₹{q.offered_price.toLocaleString()}</p>
                        <Badge status={q.status} />
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};
