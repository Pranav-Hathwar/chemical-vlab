import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/experiment_provider.dart';
import '../widgets/reactor_diagram.dart';
import '../widgets/trial_table.dart';
import '../widgets/mfr_graph.dart';
import '../utils/excel_exporter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Fixed inputs
  final _ca0Ctrl = TextEditingController();
  final _cb0Ctrl = TextEditingController();
  final _vrCtrl = TextEditingController();

  // Run inputs
  final _vaCtrl = TextEditingController();
  final _vbCtrl = TextEditingController();

  // k guess input
  final _kCtrl = TextEditingController();

  bool _isExporting = false;

  @override
  void dispose() {
    _ca0Ctrl.dispose();
    _cb0Ctrl.dispose();
    _vrCtrl.dispose();
    _vaCtrl.dispose();
    _vbCtrl.dispose();
    _kCtrl.dispose();
    super.dispose();
  }

  // Helper for numeric parsing
  double? _parse(String s) {
    final v = double.tryParse(s.trim());
    return (v != null && v > 0) ? v : null;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Logic: Check the data button
  void _onCheckData() {
    final ca0 = _parse(_ca0Ctrl.text);
    final cb0 = _parse(_cb0Ctrl.text);
    final vr = _parse(_vrCtrl.text);
    final va = _parse(_vaCtrl.text);
    final vb = _parse(_vbCtrl.text);

    if (ca0 == null || cb0 == null || vr == null) {
      _showError('All Fixed Values must be positive numbers.');
      return;
    }
    if (va == null || vb == null) {
      _showError('Values for vA and vB must be positive numbers.');
      return;
    }

    final provider = context.read<ExperimentProvider>();
    
    // Once "Check the data" is clicked for the first time, session is fixed
    if (!provider.sessionStarted) {
      final err = provider.initSession(cA0Prime: ca0, cB0Prime: cb0, vr: vr);
      if (err != null) {
        _showError(err);
        return;
      }
    }

    // Now validate the specific flow rates
    final dataErr = provider.checkData(vA: va, vB: vb);
    if (dataErr != null) {
      _showError(dataErr);
    }
  }

  void _onRunExperiment() {
    final va = _parse(_vaCtrl.text);
    final vb = _parse(_vbCtrl.text);
    if (va == null || vb == null) return;

    final provider = context.read<ExperimentProvider>();
    final result = provider.runExperiment(vA: va, vB: vb);

    if (result == null && provider.errorMessage != null) {
      _showError(provider.errorMessage!);
    }
  }

  void _onCheckResults() {
    final k = double.tryParse(_kCtrl.text.trim());
    if (k == null || k <= 0) {
      _showError('Enter a valid positive number for your determined k.');
      return;
    }
    context.read<ExperimentProvider>().submitStudentK(k);
  }

  void _onReset() {
    context.read<ExperimentProvider>().resetSession();
    _ca0Ctrl.clear();
    _cb0Ctrl.clear();
    _vrCtrl.clear();
    _vaCtrl.clear();
    _vbCtrl.clear();
    _kCtrl.clear();
  }

  Future<void> _onExport(ExperimentProvider provider) async {
    if (_isExporting) return;
    if (!provider.kRevealed) {
      _showError('Submit your k guess first before exporting.');
      return;
    }
    setState(() => _isExporting = true);
    try {
      await exportToExcel(
        trials: provider.trials,
        studentK: provider.studentK!,
        actualK: provider.revealedK!,
        cA0Prime: provider.CA0_prime!,
        cB0Prime: provider.CB0_prime!,
        vR: provider.VR!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('File exported successfully'),
            ],
          ),
          backgroundColor: const Color(0xFF388E3C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExperimentProvider>(
      builder: (context, provider, _) {
        final lockFixedInputs = provider.sessionStarted;
        final latestCa = provider.trials.isNotEmpty 
            ? provider.trials.last.CA.toStringAsFixed(4)
            : '0.0000';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA), // Modern subtle background
          appBar: AppBar(
            title: const Text('Steady State Mixed Flow Reactor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      
                      // ── DIAGRAM ────────────────────────────────────────────────
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Center(
                            child: Container(
                              width: 220,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const ReactorDiagram(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── FIXED VALUES ───────────────────────────────────────────
                      _ModernCard(
                        title: 'Fixed Values for Session',
                        icon: Icons.lock_outline,
                        iconColor: Colors.deepPurple,
                        child: Column(
                          children: [
                            _ModernInput(label: 'CA₀ (mol/L)', controller: _ca0Ctrl, enabled: !lockFixedInputs),
                            const SizedBox(height: 12),
                            _ModernInput(label: 'CB₀ (mol/L)', controller: _cb0Ctrl, enabled: !lockFixedInputs),
                            const SizedBox(height: 12),
                            _ModernInput(label: 'Vʀ (Liters)', controller: _vrCtrl, enabled: !lockFixedInputs),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── STEADY STATE RUN VALUES ────────────────────────────────
                      _ModernCard(
                        title: 'Run Input Rates',
                        icon: Icons.speed,
                        iconColor: Colors.orange,
                        child: Column(
                          children: [
                            _ModernInput(label: 'vA (L/min)', controller: _vaCtrl),
                            const SizedBox(height: 12),
                            _ModernInput(label: 'vB (L/min)', controller: _vbCtrl),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── BUTTONS ────────────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _onCheckData,
                              icon: const Icon(Icons.fact_check_outlined, size: 20),
                              label: const Text('Check Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(0xFFE8EAF6),
                                foregroundColor: const Color(0xFF1A237E),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (provider.isDataValid && provider.canRunMore) ? _onRunExperiment : null,
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: const Text('Run Trial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: provider.isDataValid ? const Color(0xFF1A237E) : Colors.grey.shade400,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── RUN RESULTS ────────────────────────────────────────────
                      Card(
                        elevation: 0,
                        color: const Color(0xFFE3F2FD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Column(
                            children: [
                              const Text(
                                'Concentration of A at Exit (Cᴀ)',
                                style: TextStyle(fontSize: 14, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$latestCa mol/L',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── CHECK RESULTS ──────────────────────────────────────────
                      if (provider.canSubmitK) ...[
                        _ModernCard(
                        title: 'Verify Results',
                        icon: Icons.calculate_outlined,
                        iconColor: Colors.teal,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _ModernInput(
                                    label: 'Determine k', 
                                    controller: _kCtrl, 
                                    enabled: !provider.kRevealed,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: (!provider.kRevealed) ? _onCheckResults : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Check', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            if (provider.kRevealed) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified, color: Colors.teal.shade600, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Actual k = ${provider.revealedK!.toStringAsFixed(5)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ],

                      // ── RESET BUTTON ───────────────────────────────────────────
                      Center(
                        child: TextButton.icon(
                          onPressed: _onReset,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Reset Session / Change k', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ── PEDAGOGICAL EXTENSIONS ─────────────────────────────────
                      if (provider.trials.isNotEmpty) ...[
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('Analysis Toolbox', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        TrialTable(trials: provider.trials),
                        const SizedBox(height: 32),
                        
                        MFRGraph(trials: provider.trials),
                      ],

                      if (provider.kRevealed) ...[
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _isExporting ? null : () => _onExport(provider),
                          icon: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download_rounded),
                          label: Text(_isExporting ? 'Exporting...' : 'Export Data to Excel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Modern Sub-widgets ──

class _ModernCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _ModernCard({
    required this.title, 
    required this.icon, 
    required this.iconColor, 
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _ModernInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;

  const _ModernInput({
    required this.label, 
    required this.controller,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }
}
