import 'package:flutter/material.dart';

class EmptyStateIllustrations {
  EmptyStateIllustrations._();

  /// No sessions illustration
  static Widget noSessions() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 100,
            color: Colors.blue.shade200,
          ),
          Positioned(
            bottom: 40,
            child: Icon(
              Icons.close,
              size: 40,
              color: Colors.blue.shade400,
            ),
          ),
        ],
      ),
    );
  }

  /// No mohaffez nearby illustration
  static Widget noMohaffezNearby() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 80,
            color: Colors.orange.shade200,
          ),
          Positioned(
            top: 50,
            right: 50,
            child: Icon(
              Icons.search,
              size: 50,
              color: Colors.orange.shade300,
            ),
          ),
        ],
      ),
    );
  }

  /// No notifications illustration
  static Widget noNotifications() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 100,
            color: Colors.purple.shade200,
          ),
        ],
      ),
    );
  }

  /// No assignments illustration
  static Widget noAssignments() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 100,
            color: Colors.green.shade200,
          ),
        ],
      ),
    );
  }

  /// No requests illustration
  static Widget noRequests() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.pending_actions,
            size: 100,
            color: Colors.amber.shade300,
          ),
        ],
      ),
    );
  }

  /// No credentials illustration
  static Widget noCredentials() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.workspace_premium,
            size: 100,
            color: Colors.blue.shade200,
          ),
        ],
      ),
    );
  }
}
