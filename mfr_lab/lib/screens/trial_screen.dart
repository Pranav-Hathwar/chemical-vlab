import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/experiment_provider.dart';
import '../widgets/input_field.dart';
import '../widgets/reactor_diagram.dart';
import '../widgets/trial_table.dart';

class TrialScreen extends StatefulWidget {
  const TrialScreen({super.key});
  @override
  State<TrialScreen> createState() => _TrialScreenState();
}

class _TrialScreenState extends State<TrialScreen> {
  final _vACtrl = TextEditingController();
  final _vBCtrl = TextEditingController();
  String? _vAError, _vBError;
  bool _navigating = false;

  @override
  void dispose() {
    _vACtrl.dispose();
    _vBCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  double? _parse(String s) {
    final v = double.tryParse(s.trim());
    return (v != null && v > 0) ? v : null;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Check Data ──────────────────────────────────────────────────────────────

  void _onCheckData() {
    setState(() { _vAError = _vBError = null; });

    final vA = _parse(_vACtrl.text);
    final vB = _parse(_vBCtrl.text);

    if (vA == null) { setState(() => _vAError = 'Enter a positive number'); return; }
    if (vB == null) { setState(() => _vBError = 'Enter a positive number'); return; }

    final error = context.read<ExperimentProvider>()
        .checkData(vA: vA, vB: vB);

    if (error != null) _showError(error);
  }

  // ── Run Experiment ──────────────────────────────────────────────────────────

  void _onRunExperiment() {
    final vA = _parse(_vACtrl.text);
    final vB = _parse(_vBCtrl.text);
    if (vA == null || vB == null) return;

    final provider = context.read<ExperimentProvider>();
    final result = provider.runExperiment(vA: vA, vB: vB);

    if (result == null) {
      if (provider.errorMessage != null) _showError(provider.errorMessage!);
      return;
    }

    // Clear inputs for next run
    _vACtrl.clear();
    _vBCtrl.clear();
    setState(() { _vAError = _vBError = null; });

    // Auto-navigate when max trials reached
    if (provider.sessionComplete && !_navigating) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/results');
      });
    }
  }

  // ── Back button guard ───────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Experiment?'),
        content: const Text(
            'Going back will end your session and discard all trial data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F)),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ExperimentProvider>(
      builder: (context, provider, _) {
        final run = provider.trialCount + 1;

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Run Trials'),
              centerTitle: true,
              automaticallyImplyLeading: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(
                    label: Text(
                      'Run ${provider.trialCount} / 12',
                      style: const TextStyle(
                        color: Color(0xFF1A237E),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: const Color(0xFFFFC107),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── Compact reactor diagram (Hero landing target) ─────────
                  const Padding(
                    padding: EdgeInsets.only(top: 14, bottom: 2),
                    child: Center(
                      child: Hero(
                        tag: 'reactor-diagram',
                        child: SizedBox(
                          width: 140,
                          height: 100,
                          child: ReactorDiagram(),
                        ),
                      ),
                    ),
                  ),

                  // ── Fixed-values summary row ─────────────────────────────
                  _FixedValuesBanner(provider: provider),
                  const SizedBox(height: 4),

                  // ── Current trial card ───────────────────────────────────
                  _SectionCard(
                    title: 'Current Trial — Run $run',
                    child: Column(
                      children: [
                        MFRInputField(
                          label: 'vA  —  Flow rate of stream A',
                          unit: 'L/min',
                          controller: _vACtrl,
                          errorText: _vAError,
                          enabled: !provider.sessionComplete,
                          onChanged: (_) {
                            setState(() => _vAError = null);
                            if (provider.isDataValid) {
                              context.read<ExperimentProvider>()
                                  .checkData(vA: _parse(_vACtrl.text) ?? 0,
                                             vB: _parse(_vBCtrl.text) ?? 0);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        MFRInputField(
                          label: 'vB  —  Flow rate of stream B',
                          unit: 'L/min',
                          controller: _vBCtrl,
                          errorText: _vBError,
                          enabled: !provider.sessionComplete,
                          onChanged: (_) {
                            setState(() => _vBError = null);
                          },
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 16),

                        // ── Action buttons ─────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: provider.sessionComplete
                                    ? null : _onCheckData,
                                child: const Text('Check Data'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (provider.isDataValid &&
                                        provider.canRunMore)
                                    ? _onRunExperiment : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: provider.isDataValid
                                      ? const Color(0xFF1A237E)
                                      : Colors.grey,
                                ),
                                child: const Text('Run Experiment'),
                              ),
                            ),
                          ],
                        ),

                        // ── Result display ─────────────────────────────────
                        if (provider.trials.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _ResultBadge(
                              ca: provider.trials.last.CA),
                        ],
                      ],
                    ),
                  ),

                  // ── Progress ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${provider.trialCount} of 12 trials completed'
                          '  ·  Minimum 3 required',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF757575)),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: provider.trialCount / 12,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE0E0E0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF1A237E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Trial table ───────────────────────────────────────────
                  if (provider.trials.isNotEmpty)
                    TrialTable(trials: provider.trials),

                  // ── View Results button ───────────────────────────────────
                  if (provider.canSubmitK) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushReplacementNamed('/results'),
                        icon: const Icon(Icons.bar_chart_rounded),
                        label: const Text('View Results →'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF388E3C),
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _FixedValuesBanner extends StatelessWidget {
  final ExperimentProvider provider;
  const _FixedValuesBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    String fmt(double? v) => v?.toStringAsFixed(3) ?? '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _InfoChip(label: "CA₀'", value: '${fmt(provider.CA0_prime)} mol/L'),
          _InfoChip(label: "CB₀'", value: '${fmt(provider.CB0_prime)} mol/L'),
          _InfoChip(label: 'VR',   value: '${fmt(provider.VR)} L'),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E)),
          children: [
            TextSpan(
              text: '$label = ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final double ca;
  const _ResultBadge({required this.ca});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            'Concentration of A at exit',
            style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 4),
          Text(
            'CA = ${ca.toStringAsFixed(5)} mol/L',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF57F17),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
