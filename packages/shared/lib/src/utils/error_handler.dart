import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts Supabase / generic exceptions into user-friendly messages.
class AppErrorHandler {
  static String getMessage(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }
}
