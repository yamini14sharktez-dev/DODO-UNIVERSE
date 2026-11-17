import React from 'react';

interface BadgeProps {
  status: string;
  variant?: 'success' | 'warning' | 'error' | 'info' | 'neutral';
  className?: string;
}

export const Badge: React.FC<BadgeProps> = ({ status, variant, className = '' }) => {
  let computedVariant = variant;
  const s = status.toLowerCase();

  if (!computedVariant) {
    if (['approved', 'active', 'completed', 'successful', 'published', 'open'].includes(s)) {
      computedVariant = 'success';
    } else if (['pending', 'under_review', 'info_requested', 'under_investigation'].includes(s)) {
      computedVariant = 'warning';
    } else if (['rejected', 'cancelled', 'disputed', 'failed', 'suspended', 'hidden', 'flagged'].includes(s)) {
      computedVariant = 'error';
    } else if (['super_admin', 'operations_admin', 'finance_admin', 'in_progress', 'draft'].includes(s)) {
      computedVariant = 'info';
    } else {
      computedVariant = 'neutral';
    }
  }

  const styles = {
    success: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    warning: 'bg-amber-50 text-amber-700 border-amber-200',
    error: 'bg-rose-50 text-rose-700 border-rose-200',
    info: 'bg-sky-50 text-sky-700 border-sky-200',
    neutral: 'bg-slate-50 text-slate-600 border-slate-200',
  };

  return (
    <span
      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border capitalize ${styles[computedVariant]} ${className}`}
    >
      <span className="w-1.5 h-1.5 rounded-full mr-1.5 bg-current opacity-75" />
      {status.replace(/_/g, ' ')}
    </span>
  );
};
