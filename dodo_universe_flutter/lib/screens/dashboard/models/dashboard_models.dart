import 'package:flutter/material.dart';

/// Categories of services available across the universal DODO Universe marketplace.
class ServiceCategory {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final int providerCount;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.providerCount = 0,
  });

  static const List<ServiceCategory> sampleCategories = [
    ServiceCategory(
      id: 'tech_repairs',
      name: 'Tech & Electronics',
      icon: Icons.devices_other_rounded,
      description: 'Laptops, screen replacements, phones, storage upgrades & OS fixes',
      providerCount: 0,
    ),
    ServiceCategory(
      id: 'home_living',
      name: 'Home & Living',
      icon: Icons.roofing_rounded,
      description: 'Appliance care, furniture setup, electrical checks & repairs',
      providerCount: 0,
    ),
    ServiceCategory(
      id: 'creative_code',
      name: 'Design & Engineering',
      icon: Icons.terminal_rounded,
      description: 'Custom web apps, UI/UX design, brand identities & coding mentorship',
      providerCount: 0,
    ),
    ServiceCategory(
      id: 'mentorship',
      name: 'Academic & Professional',
      icon: Icons.psychology_rounded,
      description: 'Subject tutoring, exam preparation, code reviews & career mentoring',
      providerCount: 0,
    ),
    ServiceCategory(
      id: 'delivery_errands',
      name: 'Errands & Delivery',
      icon: Icons.local_shipping_rounded,
      description: 'Neighborhood delivery, urgent document courier & errand services',
      providerCount: 0,
    ),
    ServiceCategory(
      id: 'events_media',
      name: 'Media & Photography',
      icon: Icons.photo_camera_rounded,
      description: 'Portrait sessions, corporate media, event photography & video editing',
      providerCount: 0,
    ),
    ServiceCategory(
      id: 'print_3d',
      name: 'Print & Fabrication',
      icon: Icons.precision_manufacturing_rounded,
      description: 'Rapid 3D prototyping, architectural prints & document binding',
      providerCount: 0,
    ),
    ServiceCategory(
      id: 'health_fitness',
      name: 'Fitness & Wellness',
      icon: Icons.self_improvement_rounded,
      description: 'Personal fitness coaching, yoga sessions & athletic nutrition',
      providerCount: 0,
    ),
  ];
}

/// Represents a verified service provider / marketplace professional.
class ServiceProvider {
  final String id;
  final String name;
  final String category;
  final String headline;
  final String initials;
  final double rating;
  final int reviewCount;
  final double startingPrice;
  final String location;
  final bool isVerified;
  final String availability;
  final int completedJobs;
  final String bio;
  final List<String> servicesOffered;

  const ServiceProvider({
    required this.id,
    required this.name,
    required this.category,
    required this.headline,
    required this.initials,
    required this.rating,
    required this.reviewCount,
    required this.startingPrice,
    required this.location,
    required this.isVerified,
    required this.availability,
    required this.completedJobs,
    required this.bio,
    required this.servicesOffered,
  });

  static const List<ServiceProvider> sampleProviders = [];
}

/// Order status enum for direct service bookings.
enum OrderStatus {
  pendingConfirmation,
  accepted,
  inProgress,
  completed,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pendingConfirmation:
        return 'Pending Confirmation';
      case OrderStatus.accepted:
        return 'Booking Accepted';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Direct service order placed by a client.
class OrderRecord {
  final String id;
  final String serviceTitle;
  final String providerName;
  final String providerInitials;
  final String category;
  final double amount;
  final DateTime orderDate;
  final DateTime? scheduledTime;
  final OrderStatus status;
  final String location;
  final String specialNotes;

  const OrderRecord({
    required this.id,
    required this.serviceTitle,
    required this.providerName,
    required this.providerInitials,
    required this.category,
    required this.amount,
    required this.orderDate,
    this.scheduledTime,
    required this.status,
    required this.location,
    this.specialNotes = '',
  });

  static const List<OrderRecord> sampleOrders = [];
}

/// Lifecycle status for custom quotation requests.
enum RequestStatus {
  submitted,
  providerResponded,
  quoteReceived,
  accepted,
  completedOrClosed,
}

extension RequestStatusExtension on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.submitted:
        return 'Request Broadcasted';
      case RequestStatus.providerResponded:
        return 'Provider Responded';
      case RequestStatus.quoteReceived:
        return 'Quotes Received';
      case RequestStatus.accepted:
        return 'Proposal Accepted';
      case RequestStatus.completedOrClosed:
        return 'Closed & Settled';
    }
  }
}

/// A quote proposal submitted by a service professional.
class QuoteProposal {
  final String providerId;
  final String providerName;
  final String initials;
  final double rating;
  final double proposedPrice;
  final String turnaroundTime;
  final String note;
  final DateTime submittedAt;

  const QuoteProposal({
    required this.providerId,
    required this.providerName,
    required this.initials,
    required this.rating,
    required this.proposedPrice,
    required this.turnaroundTime,
    required this.note,
    required this.submittedAt,
  });
}

/// Custom service request posted by a client to receive bids.
class RequestRecord {
  final String id;
  final String title;
  final String category;
  final String description;
  final double budgetEstimate;
  final DateTime createdAt;
  final RequestStatus status;
  final List<QuoteProposal> proposals;

  const RequestRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.budgetEstimate,
    required this.createdAt,
    required this.status,
    required this.proposals,
  });

  static const List<RequestRecord> sampleRequests = [];
}

/// Notification event categories in DODO Universe.
enum NotificationCategory {
  orders,
  requests,
  provider,
  payments,
  account,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationCategory category;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isRead = false,
  });

  static const List<AppNotification> sampleNotifications = [];
}
