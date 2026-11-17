import React, { useState } from 'react';
import { Send, Bell, Radio, CheckCircle } from 'lucide-react';
import { EmptyState } from '../components/common/EmptyState';

export const Notifications: React.FC = () => {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [targetRole, setTargetRole] = useState<'all' | 'customers' | 'vendors' | 'admins'>('all');
  const [broadcasts, setBroadcasts] = useState<Array<{ id: string; title: string; message: string; target: string; date: string }>>([]);
  const [isSending, setIsSending] = useState(false);
  const [sentSuccess, setSentSuccess] = useState(false);

  const handleBroadcast = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !message.trim()) return;

    setIsSending(true);
    setTimeout(() => {
      setBroadcasts([
        {
          id: `bc_${Date.now()}`,
          title,
          message,
          target: targetRole,
          date: new Date().toLocaleString(),
        },
        ...broadcasts,
      ]);
      setTitle('');
      setMessage('');
      setIsSending(false);
      setSentSuccess(true);
      setTimeout(() => setSentSuccess(false), 3000);
    }, 400);
  };

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-lg font-bold text-slate-800">Platform Notifications & Broadcasts</h2>
        <p className="text-xs text-slate-500">
          Publish system-wide notifications, service alerts, and inspect automated notification delivery logs.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Broadcast Dispatcher */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-4">
          <div className="flex items-center gap-2 pb-3 border-b border-slate-100">
            <Radio className="w-4 h-4 text-pine-700" />
            <h3 className="text-sm font-bold text-slate-800">Compose Broadcast Announcement</h3>
          </div>

          {sentSuccess && (
            <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-xs font-semibold flex items-center gap-2">
              <CheckCircle className="w-4 h-4 text-emerald-600" />
              Announcement broadcast successfully!
            </div>
          )}

          <form onSubmit={handleBroadcast} className="space-y-4 text-xs">
            <div>
              <label className="block font-bold text-slate-700 mb-1">Target Audience</label>
              <select
                value={targetRole}
                onChange={(e) => setTargetRole(e.target.value as any)}
                className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-pine-500/20"
              >
                <option value="all">All Platform Users (Customers & Vendors)</option>
                <option value="vendors">Vendors Only</option>
                <option value="customers">Customers Only</option>
                <option value="admins">Administrators Only</option>
              </select>
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Announcement Title</label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Scheduled System Upgrade"
                className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
              />
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Message Content</label>
              <textarea
                required
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                rows={4}
                placeholder="Type your announcement or alert message..."
                className="w-full p-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-pine-500/20"
              />
            </div>

            <button
              type="submit"
              disabled={isSending}
              className="w-full py-2.5 bg-pine-700 hover:bg-pine-800 text-white rounded-xl font-bold transition flex items-center justify-center gap-2 shadow-sm disabled:opacity-50"
            >
              <Send className="w-3.5 h-3.5" />
              Send Broadcast
            </button>
          </form>
        </div>

        {/* Broadcast History */}
        <div className="lg:col-span-2 bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-100">
            <div>
              <h3 className="text-sm font-bold text-slate-800">Broadcast Announcement History</h3>
              <p className="text-xs text-slate-400">Previous platform announcements delivered</p>
            </div>
            <span className="text-xs font-bold text-slate-500 font-mono">{broadcasts.length} sent</span>
          </div>

          {broadcasts.length === 0 ? (
            <EmptyState
              title="No broadcast notifications sent yet"
              description="Announcements sent via the dispatcher will be catalogued here."
              icon={<Bell className="w-6 h-6" />}
            />
          ) : (
            <div className="space-y-3">
              {broadcasts.map((b) => (
                <div key={b.id} className="p-4 bg-slate-50 border border-slate-200 rounded-xl text-xs space-y-1">
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-slate-800 text-sm">{b.title}</span>
                    <span className="text-slate-400 font-mono text-[11px]">{b.date}</span>
                  </div>
                  <p className="text-slate-600">{b.message}</p>
                  <div className="pt-2">
                    <span className="text-[10px] font-bold text-pine-800 bg-pine-50 px-2 py-0.5 rounded border border-pine-200 uppercase">
                      Target: {b.target}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
