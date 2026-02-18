import 'dart:io';
import 'package:dio/dio.dart';

/// Centralized error extraction for all BLoCs.
///
/// The Go backend always returns errors as:
///   {"success": false, "error": {"message": "some human-readable text"}}
///
/// This helper properly extracts that nested message and returns
/// user-friendly French strings for common HTTP status codes.
String extractApiError(dynamic e) {
  if (e is DioException) {
    // ── Network / timeout errors ──
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Délai de connexion dépassé. Vérifiez votre connexion.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.error is SocketException) {
      return 'Erreur réseau. Vérifiez votre connexion internet.';
    }

    // ── HTTP response errors ──
    final data = e.response?.data;
    if (data is Map) {
      // Backend format: {"error": {"message": "..."}}
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      // Fallback: {"error": "flat string"} (just in case)
      if (error is String && error.isNotEmpty) {
        return error;
      }
      // Fallback: {"message": "..."} (some endpoints)
      if (data['message'] is String) {
        return data['message'] as String;
      }
    }

    // ── Status-code based fallbacks ──
    switch (e.response?.statusCode) {
      case 400:
        return 'Requête invalide. Vérifiez les champs du formulaire.';
      case 401:
        return 'Session expirée. Veuillez vous reconnecter.';
      case 402:
        return 'Solde insuffisant. Rechargez votre portefeuille.';
      case 403:
        return 'Vous n\'avez pas les permissions nécessaires.';
      case 404:
        return 'Ressource introuvable.';
      case 409:
        return 'Un conflit a été détecté. Veuillez réessayer.';
      case 422:
        return 'Données invalides. Vérifiez les champs du formulaire.';
      case 429:
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 500:
        return 'Erreur serveur. Veuillez réessayer plus tard.';
    }

    return e.message ?? 'Une erreur est survenue. Veuillez réessayer.';
  }

  // Non-Dio errors — never expose raw technical text
  return 'Une erreur est survenue. Veuillez réessayer.';
}
