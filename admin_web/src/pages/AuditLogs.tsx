import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { AuditLog } from '../types';
import { DataTable, Column } from '../components/common/DataTable';
import { Badge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { Eye, History } from 'lucide-react';

export const AuditLogs: React.FC = () => {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [total, setTotal] = useState(0);
  const [entityFilter, setEntityFilter] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  const [offset, setOffset] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null);

  const fetchLogs = async () => {
    setIsLoading(true);
    try {
      const res = await api.getAuditLogs(entityFilter, actionFilter, 25, offset);
      setLogs(res.items || []);
      setTotal(res.total || 0);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, [entityFilter, actionFilter, offset]);

  const columns: Column<AuditLog>[] = [
    {
      header: 'Timestamp',
      accessor: 'created_at',
      render: (l) => (
        <span className="font-mono text-xs text-slate-500">
          {new Date(l.created_at).toLocaleString()}
        </span>
      ),
    },
    {
      header: 'Administrator',
      accessor: 'admin_name',
      render: (l) => (
        <div>
          <p className="font-bold text-slate-800 text-xs">{l.admin_name}</p>
          <p className="text-[10px] text-slate-400 uppercase tracking-wider">{l.admin_role}</p>
        </div>
      ),
    },
    {
      header: 'Action',
      accessor: 'action',
      render: (l) => <Badge status={l.action} />,
    },
    {
      header: 'Target Entity',
      render: (l) => (
        <div>
          <p className="font-semibold text-slate-800 text-xs capitalize">{l.entity_type}</p>
          <p className="text-[11px] text-slate-400 font-mono">ID: {l.entity_id}</p>
        </div>
      ),
    },
    {
      header: 'IP Address',
      accessor: 'ip_address',
      render: (l) => (
        <span className="font-mono text-xs text-slate-400">{l.ip_address || '-'}</span>
      ),
    },
    {
      header: 'Details',
      className: 'text-right',
      render: (l) => (
        <button
          onClick={() => setSelectedLog(l)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-pine-700 bg-pine-50 hover:bg-pine-100 transition"
        >
          <Eye className="w-3.5 h-3.5" />
          Diff Payload
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Immutable Audit Trail</h2>
          <p className="text-xs text-slate-500">
            Cryptographically chronological log of all administrative actions, data modifications, and approvals.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <select
            value={entityFilter}
            onChange={(e) => {
              setEntityFilter(e.target.value);
              setOffset(0);
            }}
            className="p-2 bg-white border border-slate-200 rounded-xl text-xs font-semibold text-slate-700"
          >
            <option value="">All Entities</option>
            <option value="user">User</option>
            <option value="vendor_application">Vendor Application</option>
            <option value="category">Category</option>
            <option value="form_definition">Form Definition</option>
            <option value="listing">Listing</option>
            <option value="order">Order</option>
            <option value="admin">Admin</option>
            <option value="setting">Setting</option>
          </select>
        </div>
      </div>

      <DataTable
        columns={columns}
        data={logs}
        total={total}
        limit={25}
        offset={offset}
        onPageChange={setOffset}
        isLoading={isLoading}
        emptyTitle="No audit log entries recorded"
        emptyDescription="All administrative writes and status transitions will be permanently preserved here."
      />

      {/* JSON Diff Modal */}
      <Modal
        isOpen={!!selectedLog}
        onClose={() => setSelectedLog(null)}
        title={`Audit Entry: ${selectedLog?.action} on ${selectedLog?.entity_type}`}
        maxWidth="lg"
      >
        {selectedLog && (
          <div className="space-y-4 text-xs">
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
              <p className="text-slate-500">
                Performed by <strong className="text-slate-800">{selectedLog.admin_name}</strong> ({selectedLog.admin_role}) from IP {selectedLog.ip_address} on {new Date(selectedLog.created_at).toLocaleString()}
              </p>
            </div>

            {selectedLog.old_values && (
              <div>
                <span className="font-bold text-slate-700 uppercase tracking-wider block mb-1">
                  Previous State (Old Values)
                </span>
                <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 font-mono text-[11px] max-h-40 overflow-y-auto">
                  <pre>{JSON.stringify(selectedLog.old_values, null, 2)}</pre>
                </div>
              </div>
            )}

            {selectedLog.new_values && (
              <div>
                <span className="font-bold text-slate-700 uppercase tracking-wider block mb-1">
                  Updated State (New Values)
                </span>
                <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 font-mono text-[11px] max-h-40 overflow-y-auto">
                  <pre>{JSON.stringify(selectedLog.new_values, null, 2)}</pre>
                </div>
              </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
};
