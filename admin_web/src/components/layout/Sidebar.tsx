import React from 'react';
import {
  LayoutDashboard,
  Users,
  FileCheck,
  Layers,
  FileText,
  Package,
  ShoppingBag,
  MessageSquareReply,
  CreditCard,
  Bell,
  StarHalf,
  ShieldAlert,
  History,
  SlidersHorizontal,
} from 'lucide-react';

export type AdminModule =
  | 'dashboard'
  | 'people'
  | 'vendor-applications'
  | 'services-categories'
  | 'form-builder'
  | 'listings'
  | 'orders'
  | 'requests-quotes'
  | 'payments-commission'
  | 'notifications'
  | 'reviews-reports'
  | 'admin-management'
  | 'audit-logs'
  | 'settings';

interface SidebarProps {
  currentModule: AdminModule;
  onSelectModule: (module: AdminModule) => void;
  userRole?: string;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentModule,
  onSelectModule,
  userRole,
}) => {
  const menuItems = [
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { id: 'people', label: 'People Management', icon: Users },
    { id: 'vendor-applications', label: 'Vendor Applications', icon: FileCheck },
    { id: 'services-categories', label: 'Services & Categories', icon: Layers },
    { id: 'form-builder', label: 'Dynamic Form Builder', icon: FileText },
    { id: 'listings', label: 'Products & Listings', icon: Package },
    { id: 'orders', label: 'Bookings & Orders', icon: ShoppingBag },
    { id: 'requests-quotes', label: 'Requests & Quotations', icon: MessageSquareReply },
    { id: 'payments-commission', label: 'Payments & Commission', icon: CreditCard },
    { id: 'notifications', label: 'Notifications', icon: Bell },
    { id: 'reviews-reports', label: 'Reviews & Reports', icon: StarHalf },
    { id: 'admin-management', label: 'Admin Management', icon: ShieldAlert, superOnly: true },
    { id: 'audit-logs', label: 'Audit Logs', icon: History },
    { id: 'settings', label: 'Settings', icon: SlidersHorizontal },
  ];

  return (
    <aside className="w-64 bg-white border-r border-slate-200 flex flex-col h-screen select-none shrink-0">
      {/* Brand Header */}
      <div className="h-16 flex items-center px-6 border-b border-slate-100 gap-3">
        <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-pine-700 to-pine-900 flex items-center justify-center text-white shadow-sm font-black text-lg">
          D
        </div>
        <div>
          <h1 className="text-sm font-bold text-slate-800 tracking-tight leading-tight">
            DODO Universe
          </h1>
          <p className="text-[11px] font-medium text-pine-700 uppercase tracking-wider">
            Admin Console
          </p>
        </div>
      </div>

      {/* Nav List */}
      <div className="flex-1 overflow-y-auto px-3 py-4 space-y-1">
        <div className="px-3 pb-2 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
          Platform Operations
        </div>
        {menuItems.map((item) => {
          if (item.superOnly && userRole !== 'super_admin') return null;

          const Icon = item.icon;
          const isActive = currentModule === item.id;

          return (
            <button
              key={item.id}
              onClick={() => onSelectModule(item.id as AdminModule)}
              className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${
                isActive
                  ? 'bg-pine-50 text-pine-800 font-bold shadow-sm border border-pine-200/50'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50'
              }`}
            >
              <Icon
                className={`w-4 h-4 transition-colors ${
                  isActive ? 'text-pine-700 stroke-[2.2]' : 'text-slate-400 group-hover:text-slate-600'
                }`}
              />
              <span className="truncate">{item.label}</span>
            </button>
          );
        })}
      </div>

      {/* Footer Info */}
      <div className="p-4 border-t border-slate-100 text-[11px] text-slate-400 bg-slate-50/50 flex items-center justify-between">
        <span>DODO Admin v1.0.0</span>
        <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" title="Go Backend Online" />
      </div>
    </aside>
  );
};
