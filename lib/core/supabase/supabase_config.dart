class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  factory SupabaseConfig.fromEnvironment() {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://skkequjojwmivdmaqczb.supabase.co',
    );
    const anonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_sgAvB-4aV-ZCns0Xn7A4vQ_JrdR4pe2',
    );

    return SupabaseConfig(url: url.trim(), anonKey: anonKey.trim());
  }

  final String url;
  final String anonKey;

  bool get isComplete => url.isNotEmpty && anonKey.isNotEmpty;

  List<String> get missingVariables => [
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];
}
