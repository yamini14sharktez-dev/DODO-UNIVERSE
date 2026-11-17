import React from 'react';
import { ChevronLeft, ChevronRight, Search } from 'lucide-react';
import { EmptyState } from './EmptyState';

export interface Column<T> {
  header: string;
  accessor?: keyof T;
  render?: (row: T) => React.ReactNode;
  className?: string;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  total?: number;
  limit?: number;
  offset?: number;
  onPageChange?: (newOffset: number) => void;
  searchValue?: string;
  onSearchChange?: (val: string) => void;
  searchPlaceholder?: string;
  isLoading?: boolean;
  emptyTitle?: string;
  emptyDescription?: string;
  actions?: React.ReactNode;
}

export function DataTable<T extends { id?: string | number }>({
  columns,
  data,
  total = 0,
  limit = 20,
  offset = 0,
  onPageChange,
  searchValue,
  onSearchChange,
  searchPlaceholder = 'Search records...',
  isLoading = false,
  emptyTitle,
  emptyDescription,
  actions,
}: DataTableProps<T>) {
  const currentPage = Math.floor(offset / limit) + 1;
  const totalPages = Math.ceil(total / limit) || 1;

  return (
    <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-sm">
      {/* Table Toolbar */}
      {(onSearchChange || actions) && (
        <div className="p-4 border-b border-slate-200 flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-50/50">
          {onSearchChange ? (
            <div className="relative w-full sm:w-80">
              <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                type="text"
                value={searchValue || ''}
                onChange={(e) => onSearchChange(e.target.value)}
                placeholder={searchPlaceholder}
                className="w-full pl-9 pr-4 py-2 text-sm bg-white border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-pine-500/20 focus:border-pine-600 transition"
              />
            </div>
          ) : (
            <div />
          )}
          {actions && <div className="flex items-center gap-2">{actions}</div>}
        </div>
      )}

      {/* Table Content */}
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm text-slate-600">
          <thead className="bg-slate-50 border-b border-slate-200 text-xs font-semibold text-slate-500 uppercase tracking-wider">
            <tr>
              {columns.map((col, idx) => (
                <th key={idx} className={`px-6 py-3.5 ${col.className || ''}`}>
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {isLoading ? (
              <tr>
                <td colSpan={columns.length} className="px-6 py-12 text-center text-slate-400">
                  <div className="flex items-center justify-center space-x-2">
                    <div className="w-2 h-2 rounded-full bg-pine-600 animate-bounce" />
                    <div className="w-2 h-2 rounded-full bg-pine-600 animate-bounce [animation-delay:0.2s]" />
                    <div className="w-2 h-2 rounded-full bg-pine-600 animate-bounce [animation-delay:0.4s]" />
                  </div>
                </td>
              </tr>
            ) : data.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="p-6">
                  <EmptyState title={emptyTitle} description={emptyDescription} />
                </td>
              </tr>
            ) : (
              data.map((row, rIdx) => (
                <tr key={row.id || rIdx} className="hover:bg-slate-50/70 transition-colors">
                  {columns.map((col, cIdx) => (
                    <td key={cIdx} className={`px-6 py-4 whitespace-nowrap ${col.className || ''}`}>
                      {col.render
                        ? col.render(row)
                        : col.accessor
                        ? String(row[col.accessor] ?? '-')
                        : '-'}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination Footer */}
      {onPageChange && total > 0 && (
        <div className="px-6 py-3 border-t border-slate-200 flex items-center justify-between text-xs text-slate-500 bg-slate-50/50">
          <span>
            Showing <strong className="font-semibold text-slate-700">{offset + 1}</strong> to{' '}
            <strong className="font-semibold text-slate-700">{Math.min(offset + limit, total)}</strong> of{' '}
            <strong className="font-semibold text-slate-700">{total}</strong> records
          </span>
          <div className="flex items-center space-x-2">
            <button
              onClick={() => onPageChange(Math.max(0, offset - limit))}
              disabled={offset === 0}
              className="p-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <span className="px-2">
              Page {currentPage} of {totalPages}
            </span>
            <button
              onClick={() => onPageChange(offset + limit)}
              disabled={offset + limit >= total}
              className="p-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
