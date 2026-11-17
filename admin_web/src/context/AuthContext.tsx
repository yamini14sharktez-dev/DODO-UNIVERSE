import React, { createContext, useContext, useState, useEffect } from 'react';
import { AdminUser, AdminAuthResponse } from '../types';
import { api } from '../api/client';

interface AuthContextType {
  admin: AdminUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (identifier: string, pass: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [admin, setAdmin] = useState<AdminUser | null>(() => {
    const saved = localStorage.getItem('dodo_admin_user');
    return saved ? JSON.parse(saved) : null;
  });
  const [isLoading, setIsLoading] = useState<boolean>(true);

  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem('dodo_admin_access_token');
      if (!token) {
        setIsLoading(false);
        return;
      }
      try {
        const current = await api.getMe();
        setAdmin(current);
        localStorage.setItem('dodo_admin_user', JSON.stringify(current));
      } catch {
        api.clearTokens();
        setAdmin(null);
      } finally {
        setIsLoading(false);
      }
    };
    checkAuth();
  }, []);

  const login = async (identifier: string, pass: string) => {
    const res: AdminAuthResponse = await api.login(identifier, pass);
    api.setTokens(res.tokens);
    setAdmin(res.admin);
    localStorage.setItem('dodo_admin_user', JSON.stringify(res.admin));
  };

  const logout = async () => {
    await api.logout();
    setAdmin(null);
  };

  return (
    <AuthContext.Provider value={{ admin, isAuthenticated: !!admin, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
