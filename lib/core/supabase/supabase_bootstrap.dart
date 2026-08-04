import 'package:financa/core/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SupabaseBootstrapStatus {
  ready,
  missingConfiguration,
  initializationFailed,
}

class SupabaseBootstrapResult {
  const SupabaseBootstrapResult._({
    required this.configuration,
    required this.status,
    this.initializationError,
  });

  factory SupabaseBootstrapResult.ready(SupabaseConfig configuration) {
    return SupabaseBootstrapResult._(
      configuration: configuration,
      status: SupabaseBootstrapStatus.ready,
    );
  }

  factory SupabaseBootstrapResult.missingConfiguration(
    SupabaseConfig configuration,
  ) {
    return SupabaseBootstrapResult._(
      configuration: configuration,
      status: SupabaseBootstrapStatus.missingConfiguration,
    );
  }

  factory SupabaseBootstrapResult.initializationFailed(
    SupabaseConfig configuration,
    Object error,
  ) {
    return SupabaseBootstrapResult._(
      configuration: configuration,
      status: SupabaseBootstrapStatus.initializationFailed,
      initializationError: error,
    );
  }

  final SupabaseConfig configuration;
  final SupabaseBootstrapStatus status;
  final Object? initializationError;

  bool get isReady => status == SupabaseBootstrapStatus.ready;
}

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static Future<SupabaseBootstrapResult> initialize() async {
    final configuration = SupabaseConfig.fromEnvironment();

    if (!configuration.isComplete) {
      return SupabaseBootstrapResult.missingConfiguration(configuration);
    }

    try {
      // supabase_flutter 2.16.0 does not export SecureLocalStorage. A secure
      // implementation requires a custom LocalStorage and a new dependency;
      // keep the package default until that dependency is intentionally added.
      await Supabase.initialize(
        url: configuration.url,
        publishableKey: configuration.anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      return SupabaseBootstrapResult.ready(configuration);
    } catch (error) {
      return SupabaseBootstrapResult.initializationFailed(
        configuration,
        error,
      );
    }
  }
}
