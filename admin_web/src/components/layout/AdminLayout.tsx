import React from 'react';
import { Sidebar, AdminModule } from './Sidebar';
import { Header } from './Header';
import { useAuth } from '../../context/AuthContext';

interface AdminLayoutProps {
  currentModule: AdminModule;
  onSelectModule: (module: AdminModule) => void;
  children: React.ReactNode;
}

export const AdminLayout: React.FC<AdminLayoutProps> = ({
  currentModule,
  onSelectModule,
  children,
}) => {
  const { admin } = useAuth();

  return (
    <div className="flex h-screen bg-[#F8F9FA] overflow-hidden">
      <Sidebar
        currentModule={currentModule}
        onSelectModule={onSelectModule}
        userRole={admin?.role}
      />
      <div className="flex-1 flex flex-col h-screen overflow-hidden">
        <Header currentModule={currentModule} />
        <main className="flex-1 overflow-y-auto p-8">
          <div className="max-w-7xl mx-auto space-y-6">{children}</div>
        </main>
      </div>
    </div>
  );
};
