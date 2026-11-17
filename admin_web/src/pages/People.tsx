import React, { useEffect, useState } from 'react';
import { api } from '../api/client';
import { Person, AdminOrder, VendorApplication, ProductListing } from '../types';
import { DataTable, Column } from '../components/common/DataTable';
import { Badge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { UserCheck, ShieldAlert, ShoppingCart, Store, Eye } from 'lucide-react';

export const People: React.FC = () => {
  const [people, setPeople] = useState<Person[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [offset, setOffset] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  // Selected person modal state
  const [selectedPerson, setSelectedPerson] = useState<Person | null>(null);
  const [customerOrders, setCustomerOrders] = useState<AdminOrder[]>([]);
  const [vendorApplications, setVendorApplications] = useState<VendorApplication[]>([]);
  const [vendorListings, setVendorListings] = useState<ProductListing[]>([]);
  const [isDetailLoading, setIsDetailLoading] = useState(false);
  const [activeTab, setActiveTab] = useState<'profile' | 'customer' | 'vendor'>('profile');

  const fetchPeople = async (term = search, pageOffset = offset) => {
    setIsLoading(true);
    try {
      const res = await api.getPeople(term, 20, pageOffset);
      setPeople(res.items || []);
      setTotal(res.total || 0);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchPeople();
  }, [offset]);

  const handleSearch = (val: string) => {
    setSearch(val);
    setOffset(0);
    fetchPeople(val, 0);
  };

  const openDetails = async (person: Person) => {
    setSelectedPerson(person);
    setIsDetailLoading(true);
    setActiveTab('profile');
    try {
      const res = await api.getPerson(person.id);
      setSelectedPerson(res.user);
      setCustomerOrders(res.orders || []);
      setVendorApplications(res.applications || []);
      setVendorListings(res.listings || []);
    } catch (err) {
      console.error(err);
    } finally {
      setIsDetailLoading(false);
    }
  };

  const handleToggleSuspend = async () => {
    if (!selectedPerson) return;
    const isCurrentlySuspended = selectedPerson.role === 'suspended';
    try {
      await api.setPersonStatus(selectedPerson.id, !isCurrentlySuspended);
      await fetchPeople();
      if (selectedPerson) {
        setSelectedPerson({
          ...selectedPerson,
          role: isCurrentlySuspended ? 'user' : 'suspended',
        });
      }
    } catch (err: any) {
      alert(err.message || 'Failed to update user status');
    }
  };

  const columns: Column<Person>[] = [
    {
      header: 'Full Name',
      accessor: 'full_name',
      render: (p) => (
        <div>
          <p className="font-bold text-slate-800">{p.full_name || 'Unnamed User'}</p>
          <p className="text-[11px] text-slate-400 font-mono">{p.id.slice(0, 13)}...</p>
        </div>
      ),
    },
    {
      header: 'Phone',
      accessor: 'phone',
      render: (p) => (
        <span className="font-mono text-xs">
          {p.phone || <span className="text-slate-400">None</span>}
        </span>
      ),
    },
    {
      header: 'Email',
      accessor: 'email',
      render: (p) => (
        <span className="text-xs">
          {p.email || <span className="text-slate-400">None</span>}
        </span>
      ),
    },
    {
      header: 'Account Status',
      render: (p) => <Badge status={p.role} />,
    },
    {
      header: 'Registration',
      render: (p) => (
        <Badge
          status={p.is_registration_complete ? 'Completed' : 'Pending'}
          variant={p.is_registration_complete ? 'success' : 'warning'}
        />
      ),
    },
    {
      header: 'Joined Date',
      render: (p) => (
        <span className="text-xs text-slate-500 font-mono">
          {new Date(p.created_at).toLocaleDateString()}
        </span>
      ),
    },
    {
      header: 'Actions',
      className: 'text-right',
      render: (p) => (
        <button
          onClick={() => openDetails(p)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-pine-700 bg-pine-50 hover:bg-pine-100 transition"
        >
          <Eye className="w-3.5 h-3.5" />
          Manage
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-bold text-slate-800">Unified People Management</h2>
        <p className="text-xs text-slate-500">
          Single unified identity model: Every registered person can participate as both a customer and a vendor.
        </p>
      </div>

      <DataTable
        columns={columns}
        data={people}
        total={total}
        limit={20}
        offset={offset}
        onPageChange={setOffset}
        searchValue={search}
        onSearchChange={handleSearch}
        searchPlaceholder="Search by name, phone, or email..."
        isLoading={isLoading}
        emptyTitle="No registered people found"
        emptyDescription="Registered customer and vendor accounts will appear here automatically."
      />

      {/* Person Detail & Activity Modal */}
      <Modal
        isOpen={!!selectedPerson}
        onClose={() => setSelectedPerson(null)}
        title={selectedPerson?.full_name || 'Person Details'}
        maxWidth="2xl"
      >
        {selectedPerson && (
          <div className="space-y-6">
            {/* Modal Tabs */}
            <div className="flex border-b border-slate-200">
              <button
                onClick={() => setActiveTab('profile')}
                className={`py-2 px-4 text-xs font-bold border-b-2 transition ${
                  activeTab === 'profile'
                    ? 'border-pine-700 text-pine-800'
                    : 'border-transparent text-slate-400 hover:text-slate-600'
                }`}
              >
                Account Profile
              </button>
              <button
                onClick={() => setActiveTab('customer')}
                className={`py-2 px-4 text-xs font-bold border-b-2 transition flex items-center gap-1.5 ${
                  activeTab === 'customer'
                    ? 'border-pine-700 text-pine-800'
                    : 'border-transparent text-slate-400 hover:text-slate-600'
                }`}
              >
                <ShoppingCart className="w-3.5 h-3.5" />
                Customer Activity ({customerOrders.length})
              </button>
              <button
                onClick={() => setActiveTab('vendor')}
                className={`py-2 px-4 text-xs font-bold border-b-2 transition flex items-center gap-1.5 ${
                  activeTab === 'vendor'
                    ? 'border-pine-700 text-pine-800'
                    : 'border-transparent text-slate-400 hover:text-slate-600'
                }`}
              >
                <Store className="w-3.5 h-3.5" />
                Vendor Activity ({vendorListings.length} listings)
              </button>
            </div>

            {isDetailLoading ? (
              <div className="py-12 text-center text-slate-400 text-xs">Loading activity records...</div>
            ) : (
              <>
                {/* Profile Tab */}
                {activeTab === 'profile' && (
                  <div className="space-y-4 text-xs">
                    <div className="grid grid-cols-2 gap-4 bg-slate-50 p-4 rounded-xl border border-slate-200">
                      <div>
                        <span className="text-slate-400 font-medium">User ID</span>
                        <p className="font-mono text-slate-800 mt-0.5">{selectedPerson.id}</p>
                      </div>
                      <div>
                        <span className="text-slate-400 font-medium">Role Status</span>
                        <div className="mt-0.5">
                          <Badge status={selectedPerson.role} />
                        </div>
                      </div>
                      <div>
                        <span className="text-slate-400 font-medium">Phone Number</span>
                        <p className="font-mono text-slate-800 mt-0.5">{selectedPerson.phone || 'None'}</p>
                      </div>
                      <div>
                        <span className="text-slate-400 font-medium">Email Address</span>
                        <p className="text-slate-800 mt-0.5">{selectedPerson.email || 'None'}</p>
                      </div>
                      <div>
                        <span className="text-slate-400 font-medium">Registration Status</span>
                        <p className="font-semibold text-slate-800 mt-0.5">
                          {selectedPerson.is_registration_complete ? 'Complete' : 'Incomplete'}
                        </p>
                      </div>
                      <div>
                        <span className="text-slate-400 font-medium">Member Since</span>
                        <p className="text-slate-800 mt-0.5 font-mono">
                          {new Date(selectedPerson.created_at).toLocaleString()}
                        </p>
                      </div>
                    </div>

                    {/* Suspension Action */}
                    <div className="p-4 rounded-xl border border-slate-200 bg-white flex items-center justify-between">
                      <div>
                        <h4 className="font-bold text-slate-800">Account Access Control</h4>
                        <p className="text-slate-500 mt-0.5">
                          {selectedPerson.role === 'suspended'
                            ? 'This account is currently suspended from logging in.'
                            : 'Suspend this user to block authentication across all channels.'}
                        </p>
                      </div>
                      <button
                        onClick={handleToggleSuspend}
                        className={`px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-1.5 transition ${
                          selectedPerson.role === 'suspended'
                            ? 'bg-emerald-600 hover:bg-emerald-700 text-white'
                            : 'bg-rose-50 text-rose-700 border border-rose-200 hover:bg-rose-100'
                        }`}
                      >
                        {selectedPerson.role === 'suspended' ? (
                          <>
                            <UserCheck className="w-4 h-4" />
                            Reactivate Account
                          </>
                        ) : (
                          <>
                            <ShieldAlert className="w-4 h-4" />
                            Suspend Account
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                )}

                {/* Customer Activity Tab */}
                {activeTab === 'customer' && (
                  <div className="space-y-3">
                    <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                      Orders Placed as Customer
                    </h4>
                    {customerOrders.length === 0 ? (
                      <p className="text-xs text-slate-400 py-6 text-center border border-dashed rounded-xl">
                        No customer orders placed yet.
                      </p>
                    ) : (
                      <div className="divide-y divide-slate-100 border rounded-xl overflow-hidden text-xs">
                        {customerOrders.map((o) => (
                          <div key={o.id} className="p-3 flex items-center justify-between">
                            <div>
                              <p className="font-bold text-slate-800">Order #{o.id.slice(0, 8)}</p>
                              <p className="text-slate-400 text-[11px]">
                                Vendor: {o.vendor_name || 'Vendor'} • {new Date(o.created_at).toLocaleDateString()}
                              </p>
                            </div>
                            <div className="text-right">
                              <p className="font-bold text-slate-800">₹{o.total_amount.toLocaleString()}</p>
                              <Badge status={o.status} className="mt-0.5" />
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                {/* Vendor Activity Tab */}
                {activeTab === 'vendor' && (
                  <div className="space-y-4">
                    <div>
                      <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
                        Vendor Verification Applications
                      </h4>
                      {vendorApplications.length === 0 ? (
                        <p className="text-xs text-slate-400 py-4 text-center border border-dashed rounded-xl">
                          No vendor applications submitted.
                        </p>
                      ) : (
                        <div className="space-y-2">
                          {vendorApplications.map((va) => (
                            <div key={va.id} className="p-3 bg-slate-50 border rounded-xl flex items-center justify-between text-xs">
                              <div>
                                <p className="font-bold text-slate-800">{va.business_name}</p>
                                <p className="text-slate-400 text-[11px]">{va.business_type || 'General Service'}</p>
                              </div>
                              <Badge status={va.status} />
                            </div>
                          ))}
                        </div>
                      )}
                    </div>

                    <div>
                      <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
                        Active Products & Services Listings
                      </h4>
                      {vendorListings.length === 0 ? (
                        <p className="text-xs text-slate-400 py-4 text-center border border-dashed rounded-xl">
                          No listings registered under this vendor.
                        </p>
                      ) : (
                        <div className="space-y-2">
                          {vendorListings.map((l) => (
                            <div key={l.id} className="p-3 border rounded-xl flex items-center justify-between text-xs">
                              <div>
                                <p className="font-bold text-slate-800">{l.title}</p>
                                <p className="text-slate-400 text-[11px]">
                                  ₹{l.unit_price} / {l.pricing_unit} • MOQ: {l.min_order_quantity}
                                </p>
                              </div>
                              <Badge status={l.approval_status} />
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
};
