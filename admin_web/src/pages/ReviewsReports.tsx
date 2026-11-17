import React, { useState } from 'react';
import { Star, AlertCircle, Download, FileSpreadsheet } from 'lucide-react';
import { EmptyState } from '../components/common/EmptyState';
import { Badge } from '../components/common/Badge';

export const ReviewsReports: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'reviews' | 'complaints'>('reviews');

  const handleExportCSV = (type: string) => {
    const csvContent = 'data:text/csv;charset=utf-8,ID,Timestamp,Type,Status,Notes\n';
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `dodo_${type}_export_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-800">Reviews & Complaints Moderation</h2>
          <p className="text-xs text-slate-500">
            Moderate community feedback, investigate reported listings, and download audit reports.
          </p>
        </div>

        <button
          onClick={() => handleExportCSV(activeTab)}
          className="px-3.5 py-2 bg-white border border-slate-200 hover:bg-slate-50 text-slate-700 rounded-xl text-xs font-bold transition flex items-center gap-1.5 shadow-sm"
        >
          <Download className="w-3.5 h-3.5" />
          Export {activeTab === 'reviews' ? 'Reviews' : 'Complaints'} (CSV)
        </button>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-6">
        {/* Tabs */}
        <div className="flex border-b border-slate-200">
          <button
            onClick={() => setActiveTab('reviews')}
            className={`py-2 px-4 text-xs font-bold border-b-2 transition flex items-center gap-1.5 ${
              activeTab === 'reviews'
                ? 'border-pine-700 text-pine-800'
                : 'border-transparent text-slate-400 hover:text-slate-600'
            }`}
          >
            <Star className="w-3.5 h-3.5" />
            Customer & Vendor Reviews (0)
          </button>
          <button
            onClick={() => setActiveTab('complaints')}
            className={`py-2 px-4 text-xs font-bold border-b-2 transition flex items-center gap-1.5 ${
              activeTab === 'complaints'
                ? 'border-pine-700 text-pine-800'
                : 'border-transparent text-slate-400 hover:text-slate-600'
            }`}
          >
            <AlertCircle className="w-3.5 h-3.5" />
            Reported Complaints (0)
          </button>
        </div>

        {activeTab === 'reviews' ? (
          <EmptyState
            title="No reviews submitted yet"
            description="When customers rate and review completed bookings or vendor services, they will appear here for moderation."
            icon={<Star className="w-6 h-6" />}
          />
        ) : (
          <EmptyState
            title="No reported complaints"
            description="Any listing violations, customer disputes, or vendor complaints will be queued here for administrative investigation."
            icon={<AlertCircle className="w-6 h-6" />}
          />
        )}
      </div>
    </div>
  );
};
