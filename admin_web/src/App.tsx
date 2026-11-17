import React, { useState } from 'react';
import { useAuth } from './context/AuthContext';
import { AdminLayout } from './components/layout/AdminLayout';
import { AdminModule } from './components/layout/Sidebar';

// Pages
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { People } from './pages/People';
import { VendorApplications } from './pages/VendorApplications';
import { ServicesCategories } from './pages/ServicesCategories';
import { FormBuilder } from './pages/FormBuilder';
import { Listings } from './pages/Listings';
import { Orders } from './pages/Orders';
import { RequestsQuotes } from './pages/RequestsQuotes';
import { Payments } from './pages/Payments';
import { Notifications } from './pages/Notifications';
import { ReviewsReports } from './pages/ReviewsReports';
import { AdminManagement } from './pages/AdminManagement';
import { AuditLogs } from './pages/AuditLogs';
import { Settings } from './pages/Settings';

export const App: React.FC = () => {
  const { isAuthenticated, isLoading } = useAuth();
  const [currentModule, setCurrentModule] = useState<AdminModule>('dashboard');

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#F8F9FA] flex items-center justify-center">
        <div className="flex items-center space-x-2 text-slate-400">
          <div className="w-3 h-3 rounded-full bg-pine-600 animate-bounce" />
          <div className="w-3 h-3 rounded-full bg-pine-600 animate-bounce [animation-delay:0.2s]" />
          <div className="w-3 h-3 rounded-full bg-pine-600 animate-bounce [animation-delay:0.4s]" />
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Login />;
  }

  const renderModuleContent = () => {
    switch (currentModule) {
      case 'dashboard':
        return <Dashboard onNavigate={setCurrentModule} />;
      case 'people':
        return <People />;
      case 'vendor-applications':
        return <VendorApplications />;
      case 'services-categories':
        return <ServicesCategories />;
      case 'form-builder':
        return <FormBuilder />;
      case 'listings':
        return <Listings />;
      case 'orders':
        return <Orders />;
      case 'requests-quotes':
        return <RequestsQuotes />;
      case 'payments-commission':
        return <Payments />;
      case 'notifications':
        return <Notifications />;
      case 'reviews-reports':
        return <ReviewsReports />;
      case 'admin-management':
        return <AdminManagement />;
      case 'audit-logs':
        return <AuditLogs />;
      case 'settings':
        return <Settings />;
      default:
        return <Dashboard onNavigate={setCurrentModule} />;
    }
  };

  return (
    <AdminLayout currentModule={currentModule} onSelectModule={setCurrentModule}>
      {renderModuleContent()}
    </AdminLayout>
  );
};
