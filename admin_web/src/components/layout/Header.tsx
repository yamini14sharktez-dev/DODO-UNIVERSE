import React from 'react';
import { LogOut, Shield } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { Badge } from '../common/Badge';

interface HeaderProps {
  currentModule: string;
}

export const Header: React.FC<HeaderProps> = ({ currentModule }) => {
  const { admin, logout } = useAuth();

  const formatTitle = (mod: string) => {
    return mod
      .split('-')
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(' ');
  };

  return (
    <header className="h-16 bg-white border-b border-slate-200 px-8 flex items-center justify-between shrink-0">
      <div>
        <h2 className="text-base font-bold text-slate-800 tracking-tight">
          {formatTitle(currentModule)}
        </h2>
        <p className="text-xs text-slate-400">Manage and monitor live system data</p>
      </div>

      <div className="flex items-center gap-4">
        {admin && (
          <div className="flex items-center gap-3 pr-2 border-r border-slate-200">
            <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-slate-600 border border-slate-200">
              <Shield className="w-4 h-4 text-pine-700" />
            </div>
            <div className="text-left hidden sm:block">
              <p className="text-xs font-bold text-slate-800 leading-none">{admin.full_name}</p>
              <p className="text-[10px] text-slate-400 leading-none mt-1">{admin.email}</p>
            </div>
            <Badge status={admin.role} className="ml-1" />
          </div>
        )}

        <button
          onClick={logout}
          className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold text-slate-600 hover:text-rose-600 hover:bg-rose-50 border border-slate-200 hover:border-rose-200 transition"
          title="Sign out of Admin Console"
        >
          <LogOut className="w-3.5 h-3.5" />
          <span className="hidden sm:inline">Logout</span>
        </button>
      </div>
    </header>
  );
};
