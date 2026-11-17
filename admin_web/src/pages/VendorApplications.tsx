import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { VendorApplication } from '../types';
import { DataTable, Column } from '../components/common/DataTable';
import { Badge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { CheckCircle2, XCircle, HelpCircle, Eye, FileText } from 'lucide-react';

export const VendorApplications: React.FC = () => {
  const [applications, setApplications] = useState<VendorApplication[]>([]);
  const [total, setTotal] = useState(0);
  const [statusFilter, setStatusFilter] = useState('');
  const [offset, setOffset] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  // Detail Modal
  const [selectedApp, setSelectedApp] = useState<VendorApplication | null>(null);
  const [actionReason, setActionReason] = useState('');
  const [actionType, setActionType] = useState<'reject' | 'info' | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchApplications = async () => {
    setIsLoading(true);
    try {
      const res = await api.getVendorApplications(statusFilter, 20, offset);
      setApplications(res.items || []);
      setTotal(res.total || 0);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchApplications();
  }, [statusFilter, offset]);

  const handleApprove = async (id: string) => {
    if (!confirm('Are you sure you want to approve this vendor application?')) return;
    setIsSubmitting(true);
    try {
      await api.approveVendorApplication(id);
      setSelectedApp(null);
      await fetchApplications();
    } catch (err: any) {
      alert(err.message || 'Approval failed');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleRejectOrInfo = async () => {
    if (!selectedApp || !actionType) return;
    if (!actionReason.trim()) {
      alert('Please enter a reason or notes for the applicant');
      return;
    }
    setIsSubmitting(true);
    try {
      if (actionType === 'reject') {
        await api.rejectVendorApplication(selectedApp.id, actionReason);
      } else {
        await api.requestInfoVendorApplication(selectedApp.id, actionReason);
      }
      setSelectedApp(null);
      setActionType(null);
      setActionReason('');
      await fetchApplications();
    } catch (err: any) {
      alert(err.message || 'Action failed');
    } finally {
      setIsSubmitting(false);
    }
  };

  const columns: Column<VendorApplication>[] = [
    {
      header: 'Business Name',
      accessor: 'business_name',
      render: (va) => (
        <div>
          <p className="font-bold text-slate-800">{va.business_name}</p>
          <p className="text-xs text-slate-400">{va.category_name || va.business_type || 'General Service'}</p>
        </div>
      ),
    },
    {
      header: 'Applicant Details',
      render: (va) => (
        <div>
          <p className="font-semibold text-slate-800 text-xs">{va.user_full_name || 'User'}</p>
          <p className="text-[11px] text-slate-400 font-mono">{va.user_phone || va.user_email}</p>
        </div>
      ),
    },
    {
      header: 'Verification Status',
      render: (va) => <Badge status={va.status} />,
    },
    {
      header: 'Submitted',
      render: (va) => (
        <span className="text-xs text-slate-500 font-mono">
          {new Date(va.created_at).toLocaleDateString()}
        </span>
      ),
    },
    {
      header: 'Actions',
      className: 'text-right',
      render: (va) => (
        <button
          onClick={() => setSelectedApp(va)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-pine-700 bg-pine-50 hover:bg-pine-100 transition"
        >
          <Eye className="w-3.5 h-3.5" />
          Review Application
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Vendor Verification Applications</h2>
          <p className="text-xs text-slate-500">
            Review onboarding requests, inspect submitted legal documentation, and manage approvals.
          </p>
        </div>

        {/* Status Filter Tabs */}
        <div className="flex items-center gap-1 bg-white p-1 rounded-xl border border-slate-200 text-xs">
          {['', 'pending', 'under_review', 'approved', 'rejected', 'info_requested'].map((st) => (
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
              {st === '' ? 'All Applications' : st.replace(/_/g, ' ')}
            </button>
          ))}
        </div>
      </div>

      <DataTable
        columns={columns}
        data={applications}
        total={total}
        limit={20}
        offset={offset}
        onPageChange={setOffset}
        isLoading={isLoading}
        emptyTitle="No vendor applications found"
        emptyDescription="When users submit applications to become vendors, they will appear here for verification."
      />

      {/* Review Modal */}
      <Modal
        isOpen={!!selectedApp}
        onClose={() => {
          setSelectedApp(null);
          setActionType(null);
          setActionReason('');
        }}
        title={`Review: ${selectedApp?.business_name}`}
        maxWidth="2xl"
      >
        {selectedApp && (
          <div className="space-y-6 text-xs">
            {/* Header Status */}
            <div className="flex items-center justify-between p-4 bg-slate-50 rounded-xl border border-slate-200">
              <div>
                <p className="font-bold text-slate-800 text-sm">{selectedApp.business_name}</p>
                <p className="text-slate-400">
                  Applicant: {selectedApp.user_full_name} ({selectedApp.user_phone})
                </p>
              </div>
              <Badge status={selectedApp.status} />
            </div>

            {/* Submitted Form Payload */}
            <div>
              <h4 className="font-bold text-slate-700 uppercase tracking-wider mb-2">
                Application Form Details
              </h4>
              <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 font-mono text-[11px] max-h-48 overflow-y-auto">
                <pre>{JSON.stringify(selectedApp.submitted_data, null, 2)}</pre>
              </div>
            </div>

            {/* Documents */}
            <div>
              <h4 className="font-bold text-slate-700 uppercase tracking-wider mb-2">
                Verification Documents
              </h4>
              {selectedApp.documents && selectedApp.documents.length > 0 ? (
                <div className="grid grid-cols-2 gap-3">
                  {selectedApp.documents.map((doc, idx) => (
                    <a
                      key={idx}
                      href={doc.url}
                      target="_blank"
                      rel="noreferrer"
                      className="p-3 bg-white border border-slate-200 rounded-xl flex items-center gap-3 hover:border-pine-400 transition"
                    >
                      <FileText className="w-5 h-5 text-pine-700 shrink-0" />
                      <div className="truncate">
                        <p className="font-bold text-slate-800 truncate">{doc.name || `Document #${idx + 1}`}</p>
                        <p className="text-[10px] text-slate-400 uppercase">{doc.type || 'File'}</p>
                      </div>
                    </a>
                  ))}
                </div>
              ) : (
                <p className="text-slate-400 italic">No document attachments provided.</p>
              )}
            </div>

            {/* Rejection / Info notes if present */}
            {selectedApp.rejection_reason && (
              <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-800">
                <p className="font-bold">Rejection Reason:</p>
                <p className="mt-0.5">{selectedApp.rejection_reason}</p>
              </div>
            )}
            {selectedApp.info_request_notes && (
              <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-amber-800">
                <p className="font-bold">Requested Information Notes:</p>
                <p className="mt-0.5">{selectedApp.info_request_notes}</p>
              </div>
            )}

            {/* Action Prompt */}
            {actionType ? (
              <div className="p-4 bg-slate-50 border border-slate-200 rounded-xl space-y-3">
                <h4 className="font-bold text-slate-800">
                  {actionType === 'reject' ? 'Rejection Reason' : 'Information to Request'}
                </h4>
                <textarea
                  value={actionReason}
                  onChange={(e) => setActionReason(e.target.value)}
                  placeholder={
                    actionType === 'reject'
                      ? 'Specify why this application is rejected...'
                      : 'Detail which document or info the vendor must submit...'
                  }
                  rows={3}
                  className="w-full p-3 bg-white border border-slate-200 rounded-xl text-xs focus:ring-2 focus:ring-pine-500/20 focus:outline-none"
                />
                <div className="flex justify-end gap-2">
                  <button
                    onClick={() => {
                      setActionType(null);
                      setActionReason('');
                    }}
                    className="px-3 py-1.5 border border-slate-200 bg-white rounded-lg font-semibold text-slate-600 hover:bg-slate-50"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleRejectOrInfo}
                    disabled={isSubmitting}
                    className="px-4 py-1.5 bg-pine-700 text-white rounded-lg font-bold hover:bg-pine-800 disabled:opacity-50"
                  >
                    Confirm {actionType === 'reject' ? 'Rejection' : 'Request'}
                  </button>
                </div>
              </div>
            ) : (
              /* Action Buttons */
              <div className="flex items-center justify-end gap-2 pt-4 border-t border-slate-100">
                <button
                  onClick={() => setActionType('reject')}
                  className="px-3.5 py-2 text-rose-700 bg-rose-50 hover:bg-rose-100 border border-rose-200 rounded-xl font-bold transition flex items-center gap-1.5"
                >
                  <XCircle className="w-4 h-4" />
                  Reject
                </button>
                <button
                  onClick={() => setActionType('info')}
                  className="px-3.5 py-2 text-amber-700 bg-amber-50 hover:bg-amber-100 border border-amber-200 rounded-xl font-bold transition flex items-center gap-1.5"
                >
                  <HelpCircle className="w-4 h-4" />
                  Request Info
                </button>
                <button
                  onClick={() => handleApprove(selectedApp.id)}
                  disabled={isSubmitting}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold transition flex items-center gap-1.5 shadow-sm"
                >
                  <CheckCircle2 className="w-4 h-4" />
                  Approve Application
                </button>
              </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
};
