import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { DashboardMetrics } from '../types';
import {
  Users,
  Store,
  FileCheck,
  Layers,
  Package,
  ShoppingBag,
  Clock,
  CheckCircle2,
  XCircle,
  MessageSquareReply,
  Activity,
  ArrowUpRight,
} from 'lucide-react';
import { Badge } from '../components/common/Badge';
import { EmptyState } from '../components/common/EmptyState';

export const Dashboard: React.FC<{ onNavigate: (page: any) => void }> = ({ onNavigate }) => {
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchMetrics = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await api.getDashboardMetrics();
      setMetrics(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load dashboard metrics');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchMetrics();
  }, []);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="flex items-center space-x-2 text-slate-400">
          <div className="w-2.5 h-2.5 rounded-full bg-pine-600 animate-bounce" />
          <div className="w-2.5 h-2.5 rounded-full bg-pine-600 animate-bounce [animation-delay:0.2s]" />
          <div className="w-2.5 h-2.5 rounded-full bg-pine-600 animate-bounce [animation-delay:0.4s]" />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6 bg-rose-50 border border-rose-200 rounded-2xl text-rose-800 text-sm">
        <p className="font-bold">Error loading live metrics:</p>
        <p className="mt-1">{error}</p>
        <button
          onClick={fetchMetrics}
          className="mt-3 px-4 py-1.5 bg-rose-600 text-white rounded-lg text-xs font-semibold hover:bg-rose-700"
        >
          Retry
        </button>
      </div>
    );
  }

  const kpis = [
    {
      label: 'Total Registered People',
      value: metrics?.total_people ?? 0,
      icon: Users,
      color: 'text-pine-700 bg-pine-50 border-pine-200/50',
      action: () => onNavigate('people'),
    },
    {
      label: 'Active Vendor Profiles',
      value: metrics?.active_vendors ?? 0,
      icon: Store,
      color: 'text-emerald-700 bg-emerald-50 border-emerald-200/50',
      action: () => onNavigate('vendor-applications'),
    },
    {
      label: 'Pending Applications',
      value: metrics?.pending_vendor_applications ?? 0,
      icon: FileCheck,
      color: 'text-amber-700 bg-amber-50 border-amber-200/50',
      action: () => onNavigate('vendor-applications'),
    },
    {
      label: 'Total Services & Categories',
      value: metrics?.total_categories ?? 0,
      icon: Layers,
      color: 'text-indigo-700 bg-indigo-50 border-indigo-200/50',
      action: () => onNavigate('services-categories'),
    },
    {
      label: 'Active Listings',
      value: metrics?.total_listings ?? 0,
      icon: Package,
      color: 'text-sky-700 bg-sky-50 border-sky-200/50',
      action: () => onNavigate('listings'),
    },
    {
      label: 'Total Orders Placed',
      value: metrics?.total_orders ?? 0,
      icon: ShoppingBag,
      color: 'text-purple-700 bg-purple-50 border-purple-200/50',
      action: () => onNavigate('orders'),
    },
    {
      label: 'Pending Orders',
      value: metrics?.pending_orders ?? 0,
      icon: Clock,
      color: 'text-amber-700 bg-amber-50 border-amber-200/50',
      action: () => onNavigate('orders'),
    },
    {
      label: 'Completed Orders',
      value: metrics?.completed_orders ?? 0,
      icon: CheckCircle2,
      color: 'text-emerald-700 bg-emerald-50 border-emerald-200/50',
      action: () => onNavigate('orders'),
    },
    {
      label: 'Cancelled Orders',
      value: metrics?.cancelled_orders ?? 0,
      icon: XCircle,
      color: 'text-rose-700 bg-rose-50 border-rose-200/50',
      action: () => onNavigate('orders'),
    },
    {
      label: 'Pending Quote Requests',
      value: metrics?.pending_quote_requests ?? 0,
      icon: MessageSquareReply,
      color: 'text-teal-700 bg-teal-50 border-teal-200/50',
      action: () => onNavigate('requests-quotes'),
    },
  ];

  return (
    <div className="space-y-8">
      {/* Platform Real-time Notice */}
      <div className="bg-gradient-to-r from-pine-900 to-pine-800 rounded-2xl p-6 text-white shadow-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-pine-700/60 text-pine-200 border border-pine-600/40 mb-2">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            Live Supabase PostgreSQL Synchronized
          </span>
          <h2 className="text-xl font-bold tracking-tight">Platform Operational Overview</h2>
          <p className="text-xs text-pine-200/80 mt-1">
            Displaying live database records. Real platform state is strictly represented.
          </p>
        </div>
        <button
          onClick={fetchMetrics}
          className="px-4 py-2 bg-white/10 hover:bg-white/20 border border-white/20 rounded-xl text-xs font-bold transition flex items-center gap-2"
        >
          <Activity className="w-3.5 h-3.5" />
          Refresh Metrics
        </button>
      </div>

      {/* Grid of KPIs */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
        {kpis.map((kpi, idx) => {
          const Icon = kpi.icon;
          return (
            <div
              key={idx}
              onClick={kpi.action}
              className="bg-white p-5 rounded-2xl border border-slate-200 hover:border-pine-300 hover:shadow-md transition-all cursor-pointer group"
            >
              <div className="flex items-center justify-between mb-3">
                <div className={`w-10 h-10 rounded-xl border flex items-center justify-center ${kpi.color}`}>
                  <Icon className="w-5 h-5 stroke-[2]" />
                </div>
                <ArrowUpRight className="w-4 h-4 text-slate-300 group-hover:text-pine-600 transition-colors" />
              </div>
              <div className="text-2xl font-black text-slate-800 tracking-tight">
                {kpi.value.toLocaleString()}
              </div>
              <div className="text-xs font-semibold text-slate-500 mt-1 truncate">
                {kpi.label}
              </div>
            </div>
          );
        })}
      </div>

      {/* Recent Platform Activity */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
        <div className="flex items-center justify-between pb-4 mb-4 border-b border-slate-100">
          <div>
            <h3 className="text-sm font-bold text-slate-800">Recent Platform Activity</h3>
            <p className="text-xs text-slate-400">Chronological trail of administrative actions</p>
          </div>
          <button
            onClick={() => onNavigate('audit-logs')}
            className="text-xs font-bold text-pine-700 hover:text-pine-800"
          >
            View Full Audit Log &rarr;
          </button>
        </div>

        {metrics?.recent_activity && metrics.recent_activity.length > 0 ? (
          <div className="divide-y divide-slate-100">
            {metrics.recent_activity.map((log) => (
              <div key={log.id} className="py-3 flex items-center justify-between text-xs">
                <div className="flex items-center gap-3">
                  <Badge status={log.action} />
                  <span className="font-semibold text-slate-800">{log.admin_name}</span>
                  <span className="text-slate-500">
                    {log.action.toLowerCase()} on <span className="font-medium text-slate-700">{log.entity_type}</span> ({log.entity_id.slice(0, 8)}...)
                  </span>
                </div>
                <span className="text-slate-400 font-mono text-[11px]">
                  {new Date(log.created_at).toLocaleString()}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <EmptyState
            title="No platform activity recorded yet"
            description="Administrative actions and state changes will appear here in real-time."
          />
        )}
      </div>
    </div>
  );
};
