import 'package:financa/core/supabase/supabase_config.dart';
import 'package:flutter/material.dart';

class SupabaseConfigurationScreen extends StatelessWidget {
  const SupabaseConfigurationScreen({
    required this.configuration,
    this.initializationError,
    super.key,
  });

  final SupabaseConfig configuration;
  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    final failedToInitialize = initializationError != null;
    final title = failedToInitialize
        ? 'Não foi possível iniciar o Finança'
        : 'Configure o Supabase para continuar';
    final description = failedToInitialize
        ? 'As variáveis foram encontradas, mas a conexão não pôde ser iniciada. Confira a URL do projeto e a chave anon e execute o aplicativo novamente.'
        : 'Defina as duas variáveis de ambiente abaixo antes de executar o aplicativo.';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 760
                ? 48.0
                : 20.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                32,
                horizontalPadding,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(
                        constraints.maxWidth >= 760 ? 40 : 24,
                      ),
                      child: Semantics(
                        container: true,
                        label: title,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SupabaseBrand(),
                            const SizedBox(height: 36),
                            Text(
                              title,
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            if (!failedToInitialize &&
                                configuration.missingVariables.isNotEmpty) ...[
                              Text(
                                'Variáveis ausentes',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              for (final variable
                                  in configuration.missingVariables)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• $variable',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              const SizedBox(height: 18),
                            ],
                            Text(
                              'Exemplo no terminal',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              child: SelectionArea(
                                child: SelectableText(
                                  'flutter run\n'
                                  '  --dart-define=SUPABASE_URL=https://seu-projeto.supabase.co\n'
                                  '  --dart-define=SUPABASE_ANON_KEY=sua-chave-anon',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Em CI/CD, forneça os mesmos valores como dart-define. A chave anon pode ser usada no aplicativo; nunca coloque uma chave service_role aqui.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SupabaseBrand extends StatelessWidget {
  const _SupabaseBrand();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Finança',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.stacked_line_chart_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text('Finança', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
