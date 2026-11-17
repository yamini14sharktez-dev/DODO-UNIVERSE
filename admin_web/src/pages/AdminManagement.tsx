import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { AdminUser, AdminRole } from '../types';
import { DataTable, Column } from '../components/common/DataTable';
import { Badge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { UserPlus, ShieldAlert, Check, X } from 'lucide-react';

export const AdminManagement: React.FC = () => {
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);

  // New admin form state
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<AdminRole>('operations_admin');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchAdmins = async () => {
    setIsLoading(true);
    try {
      const data = await api.getAdmins();
      setAdmins(data || []);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchAdmins();
  }, []);

  const handleCreateAdmin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      await api.createAdmin({
        email,
        phone,
        full_name: fullName,
        password,
        role,
      });
      setIsModalOpen(false);
      setEmail('');
      setPhone('');
      setFullName('');
      setPassword('');
      await fetchAdmins();
    } catch (err: any) {
      alert(err.message || 'Failed to create admin user');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleActive = async (admin: AdminUser) => {
    if (!confirm(`Are you sure you want to ${admin.is_active ? 'deactivate' : 'activate'} this administrator?`)) return;
    try {
      await api.updateAdmin(admin.id, {
        email: admin.email,
        phone: admin.phone,
        full_name: admin.full_name,
        role: admin.role,
        is_active: !admin.is_active,
      });
      await fetchAdmins();
    } catch (err: any) {
      alert(err.message || 'Failed to update admin');
    }
  };

  const columns: Column<AdminUser>[] = [
    {
      header: 'Administrator Name',
      accessor: 'full_name',
      render: (a) => (
        <div>
          <p className="font-bold text-slate-800">{a.full_name}</p>
          <p className="text-[11px] text-slate-400 font-mono">{a.id.slice(0, 13)}...</p>
        </div>
      ),
    },
    {
      header: 'Email / Login',
      accessor: 'email',
      render: (a) => <span className="text-xs font-semibold">{a.email}</span>,
    },
    {
      header: 'Phone',
      accessor: 'phone',
      render: (a) => <span className="font-mono text-xs">{a.phone}</span>,
    },
    {
      header: 'Role Tier',
      render: (a) => <Badge status={a.role} />,
    },
    {
      header: 'Status',
      render: (a) => (
        <Badge
          status={a.is_active ? 'Active' : 'Deactivated'}
          variant={a.is_active ? 'success' : 'error'}
        />
      ),
    },
    {
      header: 'Last Login',
      render: (a) => (
        <span className="text-xs text-slate-400 font-mono">
          {a.last_login_at ? new Date(a.last_login_at).toLocaleString() : 'Never'}
        </span>
      ),
    },
    {
      header: 'Actions',
      className: 'text-right',
      render: (a) => (
        <button
          onClick={() => handleToggleActive(a)}
          className={`px-2.5 py-1 rounded-lg text-xs font-bold transition ${
            a.is_active
              ? 'text-rose-600 hover:bg-rose-50 border border-rose-200'
              : 'text-emerald-700 hover:bg-emerald-50 border border-emerald-200'
          }`}
        >
          {a.is_active ? 'Deactivate' : 'Activate'}
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Administrator Access & Roles (RBAC)</h2>
          <p className="text-xs text-slate-500">
            Super Administrator console for creating administrators and assigning role permissions.
          </p>
        </div>

        <button
          onClick={() => setIsModalOpen(true)}
          className="px-4 py-2 bg-pine-700 hover:bg-pine-800 text-white rounded-xl text-xs font-bold transition flex items-center gap-1.5 shadow-sm"
        >
          <UserPlus className="w-4 h-4" />
          Create Administrator
        </button>
      </div>

      <DataTable
        columns={columns}
        data={admins}
        total={admins.length}
        limit={50}
        offset={0}
        isLoading={isLoading}
        emptyTitle="No administrator records"
      />

      {/* Create Admin Modal */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Provision New Administrator"
        maxWidth="md"
      >
        <form onSubmit={handleCreateAdmin} className="space-y-4 text-xs">
          <div>
            <label className="block font-bold text-slate-700 mb-1">Full Name</label>
            <input
              type="text"
              required
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="e.g. Finance Controller"
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Email (Admin Login)</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="name@dodouniverse.com"
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Phone Number</label>
            <input
              type="text"
              required
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+91..."
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Temporary Password</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••••••"
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Administrative Role Tier</label>
            <select
              value={role}
              onChange={(e) => setRole(e.target.value as AdminRole)}
              className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
            >
              <option value="operations_admin">Operations Admin (Listings, Applications, Orders)</option>
              <option value="finance_admin">Finance Admin (Payments, Payouts, Commission)</option>
              <option value="super_admin">Super Admin (Full Platform Authority)</option>
            </select>
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
            <button
              type="button"
              onClick={() => setIsModalOpen(false)}
              className="px-4 py-2 border border-slate-200 rounded-xl font-semibold text-slate-600 hover:bg-slate-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-5 py-2 bg-pine-700 hover:bg-pine-800 text-white rounded-xl font-bold transition shadow-sm disabled:opacity-50"
            >
              Create Account
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
};
