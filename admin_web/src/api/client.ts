import { AuthTokens } from '../types';

class ApiClient {
  private baseUrl = '/api/v1/admin';

  private getAccessToken(): string | null {
    return localStorage.getItem('dodo_admin_access_token');
  }

  private getRefreshToken(): string | null {
    return localStorage.getItem('dodo_admin_refresh_token');
  }

  public setTokens(tokens: AuthTokens) {
    localStorage.setItem('dodo_admin_access_token', tokens.access_token);
    localStorage.setItem('dodo_admin_refresh_token', tokens.refresh_token);
  }

  public clearTokens() {
    localStorage.removeItem('dodo_admin_access_token');
    localStorage.removeItem('dodo_admin_refresh_token');
    localStorage.removeItem('dodo_admin_user');
  }

  public async request<T = any>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = endpoint.startsWith('http') ? endpoint : `${this.baseUrl}${endpoint}`;
    const token = this.getAccessToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(options.headers as Record<string, string> || {}),
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    let response = await fetch(url, { ...options, headers });

    // Handle 401: try refreshing token
    if (response.status === 401 && !endpoint.includes('/auth/login') && !endpoint.includes('/auth/refresh')) {
      const refreshed = await this.tryRefreshToken();
      if (refreshed) {
        headers['Authorization'] = `Bearer ${this.getAccessToken()}`;
        response = await fetch(url, { ...options, headers });
      } else {
        this.clearTokens();
        window.location.href = '#login';
        throw new Error('Session expired. Please log in again.');
      }
    }

    if (!response.ok) {
      let errorMsg = `HTTP Error ${response.status}`;
      try {
        const errorJson = await response.json();
        errorMsg = errorJson.message || errorJson.error || errorMsg;
      } catch {}
      throw new Error(errorMsg);
    }

    if (response.status === 204) {
      return {} as T;
    }

    return response.json();
  }

  private async tryRefreshToken(): Promise<boolean> {
    const refreshToken = this.getRefreshToken();
    if (!refreshToken) return false;

    try {
      const res = await fetch(`${this.baseUrl}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });
      if (!res.ok) return false;
      const data: AuthTokens = await res.json();
      this.setTokens(data);
      return true;
    } catch {
      return false;
    }
  }

  // Auth
  login(identifier: string, password: string) {
    return this.request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password }),
    });
  }

  logout() {
    const refreshToken = this.getRefreshToken();
    this.clearTokens();
    if (refreshToken) {
      return this.request('/auth/logout', {
        method: 'POST',
        body: JSON.stringify({ refresh_token: refreshToken }),
      }).catch(() => {});
    }
    return Promise.resolve();
  }

  getMe() {
    return this.request('/auth/me');
  }

  // Dashboard
  getDashboardMetrics() {
    return this.request('/dashboard/metrics');
  }

  // People
  getPeople(search = '', limit = 20, offset = 0) {
    return this.request(`/people?search=${encodeURIComponent(search)}&limit=${limit}&offset=${offset}`);
  }

  getPerson(id: string) {
    return this.request(`/people/${id}`);
  }

  setPersonStatus(id: string, suspended: boolean) {
    return this.request(`/people/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ suspended }),
    });
  }

  // Vendor Applications
  getVendorApplications(status = '', limit = 20, offset = 0) {
    return this.request(`/vendor-applications?status=${encodeURIComponent(status)}&limit=${limit}&offset=${offset}`);
  }

  getVendorApplication(id: string) {
    return this.request(`/vendor-applications/${id}`);
  }

  approveVendorApplication(id: string) {
    return this.request(`/vendor-applications/${id}/approve`, { method: 'POST' });
  }

  rejectVendorApplication(id: string, reason: string) {
    return this.request(`/vendor-applications/${id}/reject`, {
      method: 'POST',
      body: JSON.stringify({ reason }),
    });
  }

  requestInfoVendorApplication(id: string, notes: string) {
    return this.request(`/vendor-applications/${id}/request-info`, {
      method: 'POST',
      body: JSON.stringify({ notes }),
    });
  }

  // Categories
  getCategories() {
    return this.request('/categories');
  }

  createCategory(data: any) {
    return this.request('/categories', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  updateCategory(id: string, data: any) {
    return this.request(`/categories/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  deleteCategory(id: string) {
    return this.request(`/categories/${id}`, { method: 'DELETE' });
  }

  // Form Builder
  getFormDefinition(categoryId: string) {
    return this.request(`/forms/${categoryId}`);
  }

  saveFormDefinition(categoryId: string, form: any) {
    return this.request(`/forms/${categoryId}`, {
      method: 'POST',
      body: JSON.stringify(form),
    });
  }

  // Listings
  getListings(status = '', limit = 20, offset = 0) {
    return this.request(`/listings?status=${encodeURIComponent(status)}&limit=${limit}&offset=${offset}`);
  }

  updateListingApproval(id: string, approval: string) {
    return this.request(`/listings/${id}/approval`, {
      method: 'PATCH',
      body: JSON.stringify({ approval }),
    });
  }

  updateListingStatus(id: string, active: boolean) {
    return this.request(`/listings/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ active }),
    });
  }

  // Orders
  getOrders(status = '', search = '', limit = 20, offset = 0) {
    return this.request(`/orders?status=${encodeURIComponent(status)}&search=${encodeURIComponent(search)}&limit=${limit}&offset=${offset}`);
  }

  getOrder(id: string) {
    return this.request(`/orders/${id}`);
  }

  resolveOrderDispute(id: string, resolution: string) {
    return this.request(`/orders/${id}/dispute`, {
      method: 'PATCH',
      body: JSON.stringify({ resolution }),
    });
  }

  // Quotes
  getQuotationRequests(status = '', limit = 20, offset = 0) {
    return this.request(`/quotes/requests?status=${encodeURIComponent(status)}&limit=${limit}&offset=${offset}`);
  }

  getQuotationRequest(id: string) {
    return this.request(`/quotes/requests/${id}`);
  }

  // Payments & Commission
  getPayments(type = '', status = '', limit = 20, offset = 0) {
    return this.request(`/finance/transactions?type=${encodeURIComponent(type)}&status=${encodeURIComponent(status)}&limit=${limit}&offset=${offset}`);
  }

  getCommissionRules() {
    return this.request('/finance/commissions');
  }

  setCommissionRule(rule: any) {
    return this.request('/finance/commissions', {
      method: 'PUT',
      body: JSON.stringify(rule),
    });
  }

  // Admins (Super Admin only)
  getAdmins() {
    return this.request('/admins');
  }

  createAdmin(data: any) {
    return this.request('/admins', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  updateAdmin(id: string, data: any) {
    return this.request(`/admins/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    });
  }

  // Audit Logs
  getAuditLogs(entityType = '', action = '', limit = 20, offset = 0) {
    return this.request(`/audit-logs?entity_type=${encodeURIComponent(entityType)}&action=${encodeURIComponent(action)}&limit=${limit}&offset=${offset}`);
  }

  // Settings
  getSettings() {
    return this.request('/settings');
  }

  updateSetting(key: string, value: any) {
    return this.request('/settings', {
      method: 'PUT',
      body: JSON.stringify({ key, value }),
    });
  }
}

export const api = new ApiClient();
