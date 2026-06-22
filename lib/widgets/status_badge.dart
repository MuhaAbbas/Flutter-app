import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize = 12});

  static ({Color bg, Color text}) _colors(String s) {
    switch (s.toLowerCase().trim()) {
      case 'present':
        return (bg: const Color(0xFF1B3B2E), text: const Color(0xFF4ADE80));
      case 'absent':
        return (bg: const Color(0xFF3B1B1F), text: const Color(0xFFF87171));
      case 'leave':
      case 'on leave':
        return (bg: const Color(0xFF3B321B), text: const Color(0xFFFBBF24));
      case 'late':
      case 'half-day':
      case 'half day':
        return (bg: const Color(0xFF1B2E3B), text: const Color(0xFF60A5FA));
      case 'pending':
        return (bg: const Color(0xFF2E1B3B), text: const Color(0xFFC084FC));
      case 'approved':
      case 'paid':
      case 'active':
      case 'completed':
      case 'ongoing':
        return (bg: const Color(0xFF1B3B2E), text: const Color(0xFF4ADE80));
      case 'rejected':
      case 'inactive':
        return (bg: const Color(0xFF3B1B1F), text: const Color(0xFFF87171));
      case 'processing':
      case 'upcoming':
        return (bg: const Color(0xFF1B2E3B), text: const Color(0xFF60A5FA));
      case 'cancelled':
        return (bg: const Color(0xFF2A2A2A), text: const Color(0xFF9CA3AF));
      default:
        return (bg: const Color(0xFF252525), text: const Color(0xFFB0B0B0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors(status);
    final display = status.isEmpty ? '—'
        : '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        display,
        style: GoogleFonts.inter(
          color: c.text,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
