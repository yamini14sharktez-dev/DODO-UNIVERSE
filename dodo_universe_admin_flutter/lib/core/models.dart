class AdminUser {
  final String id;
  final String email;
  final String phone;
  final String fullName;
  final String role;
  final bool isActive;
  final String? lastLoginAt;
  final String createdAt;

  AdminUser({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'operations_admin',
      isActive: json['is_active'] ?? true,
      lastLoginAt: json['last_login_at'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'full_name': fullName,
    'role': role,
    'is_active': isActive,
    'last_login_at': lastLoginAt,
    'created_at': createdAt,
  };
}

class DashboardMetrics {
  final int totalPeople;
  final int activeVendors;
  final int pendingVendorApplications;
  final int totalServices;
  final int totalCategories;
  final int totalListings;
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int pendingQuoteRequests;
  final double totalPaymentVolume;
  final List<AuditLogItem> recentActivity;

  DashboardMetrics({
    required this.totalPeople,
    required this.activeVendors,
    required this.pendingVendorApplications,
    required this.totalServices,
    required this.totalCategories,
    required this.totalListings,
    required this.totalOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.pendingQuoteRequests,
    required this.totalPaymentVolume,
    required this.recentActivity,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      totalPeople: json['total_people'] ?? 0,
      activeVendors: json['active_vendors'] ?? 0,
      pendingVendorApplications: json['pending_vendor_applications'] ?? 0,
      totalServices: json['total_services'] ?? 0,
      totalCategories: json['total_categories'] ?? 0,
      totalListings: json['total_listings'] ?? 0,
      totalOrders: json['total_orders'] ?? 0,
      pendingOrders: json['pending_orders'] ?? 0,
      completedOrders: json['completed_orders'] ?? 0,
      cancelledOrders: json['cancelled_orders'] ?? 0,
      pendingQuoteRequests: json['pending_quote_requests'] ?? 0,
      totalPaymentVolume: (json['total_payment_volume'] as num?)?.toDouble() ?? 0.0,
      recentActivity: (json['recent_activity'] as List<dynamic>?)
              ?.map((e) => AuditLogItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class Person {
  final String id;
  final String phone;
  final String? email;
  final String fullName;
  final String role;
  final bool isRegistrationComplete;
  final String createdAt;

  Person({
    required this.id,
    required this.phone,
    this.email,
    required this.fullName,
    required this.role,
    required this.isRegistrationComplete,
    required this.createdAt,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'user',
      isRegistrationComplete: json['is_registration_complete'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class VendorApplicationItem {
  final String id;
  final String userId;
  final String userFullName;
  final String userPhone;
  final String? userEmail;
  final String businessName;
  final String? businessType;
  final String status;
  final Map<String, dynamic> submittedData;
  final List<dynamic> documents;
  final String? rejectionReason;
  final String? infoRequestNotes;
  final String createdAt;

  VendorApplicationItem({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.userPhone,
    this.userEmail,
    required this.businessName,
    this.businessType,
    required this.status,
    required this.submittedData,
    required this.documents,
    this.rejectionReason,
    this.infoRequestNotes,
    required this.createdAt,
  });

  factory VendorApplicationItem.fromJson(Map<String, dynamic> json) {
    return VendorApplicationItem(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userFullName: json['user_full_name'] ?? '',
      userPhone: json['user_phone'] ?? '',
      userEmail: json['user_email'],
      businessName: json['business_name'] ?? '',
      businessType: json['business_type'],
      status: json['status'] ?? 'pending',
      submittedData: json['submitted_data'] is Map<String, dynamic>
          ? json['submitted_data']
          : {},
      documents: json['documents'] is List ? json['documents'] : [],
      rejectionReason: json['rejection_reason'],
      infoRequestNotes: json['info_request_notes'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ServiceCategoryItem {
  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final String categoryType;
  final bool allowListings;
  final List<ServiceCategoryItem> children;

  ServiceCategoryItem({
    required this.id,
    this.parentId,
    required this.name,
    required this.slug,
    this.description,
    required this.isActive,
    required this.sortOrder,
    required this.categoryType,
    required this.allowListings,
    this.children = const [],
  });

  factory ServiceCategoryItem.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryItem(
      id: json['id'] ?? '',
      parentId: json['parent_id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
      categoryType: json['category_type'] ?? 'container',
      allowListings: json['allow_listings'] ?? false,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => ServiceCategoryItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class FormFieldItem {
  final String id;
  final String type;
  final String label;
  final String? placeholder;
  final bool required;
  final List<String>? options;

  FormFieldItem({
    required this.id,
    required this.type,
    required this.label,
    this.placeholder,
    this.required = false,
    this.options,
  });

  factory FormFieldItem.fromJson(Map<String, dynamic> json) {
    return FormFieldItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'text',
      label: json['label'] ?? '',
      placeholder: json['placeholder'],
      required: json['required'] ?? false,
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'label': label,
    'placeholder': placeholder,
    'required': required,
    if (options != null) 'options': options,
  };
}

class ProductListingItem {
  final String id;
  final String vendorId;
  final String? vendorName;
  final String categoryId;
  final String? categoryName;
  final String title;
  final String? description;
  final String listingType;
  final double unitPrice;
  final String pricingUnit;
  final double minOrderQuantity;
  final bool hasTransportation;
  final double transportationFee;
  final bool isActive;
  final String approvalStatus;

  ProductListingItem({
    required this.id,
    required this.vendorId,
    this.vendorName,
    required this.categoryId,
    this.categoryName,
    required this.title,
    this.description,
    required this.listingType,
    required this.unitPrice,
    required this.pricingUnit,
    required this.minOrderQuantity,
    required this.hasTransportation,
    required this.transportationFee,
    required this.isActive,
    required this.approvalStatus,
  });

  factory ProductListingItem.fromJson(Map<String, dynamic> json) {
    return ProductListingItem(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      vendorName: json['vendor_name'],
      categoryId: json['category_id'] ?? '',
      categoryName: json['category_name'],
      title: json['title'] ?? '',
      description: json['description'],
      listingType: json['listing_type'] ?? 'product_only',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      pricingUnit: json['pricing_unit'] ?? 'piece',
      minOrderQuantity: (json['min_order_quantity'] as num?)?.toDouble() ?? 1.0,
      hasTransportation: json['has_transportation'] ?? false,
      transportationFee: (json['transportation_fee'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
      approvalStatus: json['approval_status'] ?? 'pending',
    );
  }
}

class AdminOrderItem {
  final String id;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String vendorId;
  final String? vendorName;
  final String? vendorPhone;
  final String status;
  final double totalAmount;
  final double commissionAmount;
  final Map<String, dynamic> orderDetails;
  final String? disputeReason;
  final String? disputeResolution;
  final String createdAt;

  AdminOrderItem({
    required this.id,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.vendorId,
    this.vendorName,
    this.vendorPhone,
    required this.status,
    required this.totalAmount,
    required this.commissionAmount,
    required this.orderDetails,
    this.disputeReason,
    this.disputeResolution,
    required this.createdAt,
  });

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderItem(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      vendorId: json['vendor_id'] ?? '',
      vendorName: json['vendor_name'],
      vendorPhone: json['vendor_phone'],
      status: json['status'] ?? 'pending',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0.0,
      orderDetails: json['order_details'] is Map<String, dynamic>
          ? json['order_details']
          : {},
      disputeReason: json['dispute_reason'],
      disputeResolution: json['dispute_resolution'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class QuotationRequestItem {
  final String id;
  final String customerId;
  final String? customerName;
  final String? categoryName;
  final String title;
  final Map<String, dynamic> details;
  final String status;
  final List<dynamic> quotations;
  final String createdAt;

  QuotationRequestItem({
    required this.id,
    required this.customerId,
    this.customerName,
    this.categoryName,
    required this.title,
    required this.details,
    required this.status,
    required this.quotations,
    required this.createdAt,
  });

  factory QuotationRequestItem.fromJson(Map<String, dynamic> json) {
    return QuotationRequestItem(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'],
      categoryName: json['category_name'],
      title: json['title'] ?? '',
      details: json['details'] is Map<String, dynamic> ? json['details'] : {},
      status: json['status'] ?? 'open',
      quotations: json['quotations'] is List ? json['quotations'] : [],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PaymentRecordItem {
  final String id;
  final String? orderId;
  final String? payerName;
  final double amount;
  final String paymentType;
  final String status;
  final String? referenceNumber;
  final String createdAt;

  PaymentRecordItem({
    required this.id,
    this.orderId,
    this.payerName,
    required this.amount,
    required this.paymentType,
    required this.status,
    this.referenceNumber,
    required this.createdAt,
  });

  factory PaymentRecordItem.fromJson(Map<String, dynamic> json) {
    return PaymentRecordItem(
      id: json['id'] ?? '',
      orderId: json['order_id'],
      payerName: json['payer_name'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: json['payment_type'] ?? 'order_payment',
      status: json['status'] ?? 'pending',
      referenceNumber: json['reference_number'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class CommissionRuleItem {
  final String id;
  final String? categoryId;
  final String? categoryName;
  final double commissionPercent;
  final double fixedFee;
  final bool isActive;

  CommissionRuleItem({
    required this.id,
    this.categoryId,
    this.categoryName,
    required this.commissionPercent,
    required this.fixedFee,
    required this.isActive,
  });

  factory CommissionRuleItem.fromJson(Map<String, dynamic> json) {
    return CommissionRuleItem(
      id: json['id'] ?? '',
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      commissionPercent: (json['commission_percent'] as num?)?.toDouble() ?? 10.0,
      fixedFee: (json['fixed_fee'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
    );
  }
}

class AuditLogItem {
  final String id;
  final String adminName;
  final String adminRole;
  final String action;
  final String entityType;
  final String entityId;
  final dynamic oldValues;
  final dynamic newValues;
  final String? ipAddress;
  final String createdAt;

  AuditLogItem({
    required this.id,
    required this.adminName,
    required this.adminRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id'] ?? '',
      adminName: json['admin_name'] ?? 'System',
      adminRole: json['admin_role'] ?? 'operations_admin',
      action: json['action'] ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'] ?? '',
      oldValues: json['old_values'],
      newValues: json['new_values'],
      ipAddress: json['ip_address'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
