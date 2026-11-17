import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { SlidersHorizontal, CheckCircle, Save } from 'lucide-react';

export const Settings: React.FC = () => {
  const [settings, setSettings] = useState<Record<string, any>>({});
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [maintenanceMessage, setMaintenanceMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    const loadSettings = async () => {
      setIsLoading(true);
      try {
        const data = await api.getSettings();
        setSettings(data);
        if (data.platform_maintenance_mode) {
          setMaintenanceMode(data.platform_maintenance_mode.enabled || false);
          setMaintenanceMessage(data.platform_maintenance_mode.message || '');
        }
      } catch (err) {
        console.error(err);
      } finally {
        setIsLoading(false);
      }
    };
    loadSettings();
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setSaveSuccess(false);
    try {
      await api.updateSetting('platform_maintenance_mode', {
        enabled: maintenanceMode,
        message: maintenanceMessage,
      });
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (err: any) {
      alert(err.message || 'Failed to update settings');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="space-y-6 max-w-3xl">
      <div>
        <h2 className="text-lg font-bold text-slate-800">Platform Settings & Control</h2>
        <p className="text-xs text-slate-500">
          Global administrative configuration, security boundaries, and operational toggles.
        </p>
      </div>

      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-6">
        {saveSuccess && (
          <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-xs font-semibold flex items-center gap-2">
            <CheckCircle className="w-4 h-4 text-emerald-600" />
            Platform configuration updated and applied!
          </div>
        )}

        <form onSubmit={handleSave} className="space-y-6 text-xs">
          {/* Maintenance Mode */}
          <div className="p-4 bg-slate-50 border border-slate-200 rounded-xl space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="font-bold text-slate-800 text-sm">System Maintenance Mode</h4>
                <p className="text-slate-500 text-xs mt-0.5">
                  Temporarily restrict customer and vendor application access during critical upgrades.
                </p>
              </div>
              <input
                type="checkbox"
                checked={maintenanceMode}
                onChange={(e) => setMaintenanceMode(e.target.checked)}
                className="w-5 h-5 text-pine-700 rounded border-slate-300 focus:ring-pine-500"
              />
            </div>

            {maintenanceMode && (
              <div className="pt-2 border-t border-slate-200">
                <label className="block font-bold text-slate-700 mb-1">
                  Public Maintenance Notice Message
                </label>
                <input
                  type="text"
                  value={maintenanceMessage}
                  onChange={(e) => setMaintenanceMessage(e.target.value)}
                  placeholder="e.g. DODO Universe is undergoing scheduled database maintenance..."
                  className="w-full p-2.5 bg-white border border-slate-200 rounded-xl focus:ring-2 focus:ring-pine-500/20 focus:outline-none"
                />
              </div>
            )}
          </div>

          <div className="p-4 bg-slate-50 border border-slate-200 rounded-xl space-y-2">
            <h4 className="font-bold text-slate-800 text-sm">Security & Database Boundaries</h4>
            <div className="space-y-1 text-slate-500 text-xs">
              <p>• Database engine: Supabase Managed PostgreSQL 17 (ap-south-1)</p>
              <p>• Auth isolation: Separate Go JWT engine for admin console</p>
              <p>• Login lockout: 5 consecutive failed attempts trigger a 15-minute freeze</p>
              <p>• Zero mock policy: Live PostgreSQL aggregation enforced</p>
            </div>
          </div>

          <div className="flex justify-end">
            <button
              type="submit"
              disabled={isSaving}
              className="px-5 py-2.5 bg-pine-700 hover:bg-pine-800 text-white rounded-xl font-bold transition flex items-center gap-2 shadow-sm disabled:opacity-50"
            >
              <Save className="w-4 h-4" />
              Save Configuration
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
