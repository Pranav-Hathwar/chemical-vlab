import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

import '../models/trial_model.dart';

// ─── Top-level function (called by ResultsScreen) ─────────────────────────────

/// Convenience wrapper kept for backward compatibility with ResultsScreen.
Future<String?> exportToExcel({
  required List<TrialModel> trials,
  required double studentK,
  required double actualK,
  required double cA0Prime,  // already stored on each TrialModel
  required double cB0Prime,
  required double vR,
  String saveMode = 'share',
}) =>
    ExcelExporter.export(trials, studentK, actualK, saveMode);

// ─── Excel Exporter ───────────────────────────────────────────────────────────

/// Generates a two-sheet Excel workbook from the completed MFR session
/// and opens the system share sheet to save or send the file.
abstract final class ExcelExporter {
  // ── Column definitions: Sheet 1 ──────────────────────────────────────────────
  static const List<String> _trialHeaders = [
    'Run No.',
    "CA0' (mol/L)",
    "CB0' (mol/L)",
    'VR (L)',
    'vA (L/min)',
    'vB (L/min)',
    'CA0 (mol/L)',
    'CB0 (mol/L)',
    'τ (min)',
    'm',
    'XA',
    'CA (mol/L)',
    'CB (mol/L)',
    'CA·CB (mol²/L²)',
    'rA (mol/L·min)',
    'k per trial (L/mol·min)',
    'Y = XA / [CA0(1-XA)(m-XA)]',
  ]; // 17 columns → A..Q

  // ── Column definitions: Sheet 2 ──────────────────────────────────────────────
  static const List<String> _graphHeaders = [
    'τ (min)',
    'Y = XA / [CA0(1-XA)(m-XA)]',
  ];

  // ── Palette (ARGB hex, no '#') ───────────────────────────────────────────────
  static final ExcelColor _deepBlue   = ExcelColor.fromHexString('FF1A237E');
  static final ExcelColor _white      = ExcelColor.fromHexString('FFFFFFFF');
  static final ExcelColor _lightGrey  = ExcelColor.fromHexString('FFF5F5F5');
  static final ExcelColor _summaryBg  = ExcelColor.fromHexString('FFE8EAF6');

  // ── Public entry point ───────────────────────────────────────────────────────

  /// Builds the workbook, writes it to a temp file, and opens the share sheet.
  ///
  /// Throws an [Exception] with a descriptive message on failure.
  static Future<String?> export(
    List<TrialModel> trials,
    double studentK,
    double actualK,
    String saveMode,
  ) async {
    if (trials.isEmpty) {
      throw Exception('No trial data to export. Complete at least one trial.');
    }

    // ── 1. Build workbook ──────────────────────────────────────────────────────
    final excel = Excel.createExcel();

    // Safely rename the auto-created default sheet and set it as active
    if (excel.sheets.containsKey('Sheet1')) {
      excel.rename('Sheet1', 'Trial Data');
      excel.setDefaultSheet('Trial Data');
    }

    _buildTrialDataSheet(excel, trials, studentK, actualK);
    _buildGraphDataSheet(excel, trials);

    // ── 2. Encode ──────────────────────────────────────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel workbook. Please try again.');
    }

    final dateStr = DateFormat('dd-MM-yyyy_HH-mm').format(DateTime.now());
    final fileName = 'MFR_Lab_$dateStr.xlsx';
    const mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    if (kIsWeb) {
      // ── 3. Web Download ──────────────────────────────────────────────────────
      // The Web Share API is often blocked on Chromium desktop (e.g. without HTTPS).
      // We forcefully trigger a direct file download using a hidden HTML anchor tag.
      final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = fileName;
        
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
      return 'Downloads folder';
    } else {
      if (saveMode == 'save') {
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
        } else {
          dir = await getDownloadsDirectory();
          dir ??= await getApplicationDocumentsDirectory();
        }
        
        if (dir != null && !await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        final filePath = '${dir?.path ?? ''}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        return filePath;
      } else {
        // ── 3. Mobile / Desktop Native Share ─────────────────────────────────────
        // Requires writing to temporary disk space first so the OS share sheet can read it.
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);

        if (!await file.exists()) {
          throw Exception('Could not save file to temporary storage.');
        }

        // ── 4. Share ─────────────────────────────────────────────────────────────
        await Share.shareXFiles(
          [XFile(filePath, mimeType: mimeType)],
          subject: 'MFR Virtual Lab Results — $dateStr',
          text: 'MFR Lab trial data and graphical k determination results.',
        );
        return null;
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  SHEET 1  —  Trial Data
  // ════════════════════════════════════════════════════════════════════════════

  static void _buildTrialDataSheet(
    Excel excel,
    List<TrialModel> trials,
    double studentK,
    double actualK,
  ) {
    final sheet = excel['Trial Data'];
    final int totalCols = _trialHeaders.length; // 13

    // ── Row 0 (Excel Row 1): App title ─────────────────────────────────────────
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: _deepBlue,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    _set(sheet, 0, 0, TextCellValue('MFR Virtual Lab — Trial Data'), titleStyle);

    // Merge A1 across all columns
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0),
    );

    // ── Row 1 (Excel Row 2): Empty spacer ──────────────────────────────────────
    // (nothing to write)

    // ── Row 2 (Excel Row 3): Column headers ────────────────────────────────────
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: _deepBlue,
      fontColorHex: _white,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    for (int c = 0; c < _trialHeaders.length; c++) {
      _set(sheet, 2, c, TextCellValue(_trialHeaders[c]), headerStyle);
    }

    // ── Rows 3…N+2: One row per trial ──────────────────────────────────────────
    for (int i = 0; i < trials.length; i++) {
      final t    = trials[i];
      final row  = i + 3;
      final bg   = i.isEven ? _white : _lightGrey;
      final style = CellStyle(
        backgroundColorHex: bg,
        horizontalAlign: HorizontalAlign.Center,
      );

      final values = <CellValue>[
        IntCellValue(t.runNumber),
        DoubleCellValue(_r(t.CA0_prime)),
        DoubleCellValue(_r(t.CB0_prime)),
        DoubleCellValue(_r(t.VR)),
        DoubleCellValue(_r(t.vA)),
        DoubleCellValue(_r(t.vB)),
        DoubleCellValue(_r(t.CA0)),
        DoubleCellValue(_r(t.CB0)),
        DoubleCellValue(_r(t.tau)),
        DoubleCellValue(_r(t.m)),
        DoubleCellValue(_r(t.XA)),
        DoubleCellValue(_r(t.CA)),
        DoubleCellValue(_r(t.CB)),
        DoubleCellValue(_r(t.CACB)),
        DoubleCellValue(_r(t.rA)),
        DoubleCellValue(_r(t.kPerTrial)),
        DoubleCellValue(_r(t.graphY)),
      ];

      for (int c = 0; c < values.length; c++) {
        _set(sheet, row, c, values[c], style);
      }
    }

    // ── Summary rows (after one blank row) ────────────────────────────────────
    final int lastDataRow  = trials.length + 3; // 0-indexed
    final int summaryStart = lastDataRow + 1;   // +1 blank spacer

    final labelStyle = CellStyle(
      bold: true,
      backgroundColorHex: _summaryBg,
      fontColorHex: _deepBlue,
      horizontalAlign: HorizontalAlign.Left,
    );
    final valueStyle = CellStyle(
      bold: true,
      backgroundColorHex: _summaryBg,
      fontColorHex: _deepBlue,
      horizontalAlign: HorizontalAlign.Center,
    );
    final pctError = (studentK - actualK).abs() / actualK * 100;

    final summaryRows = [
      ["Student's Determined k",  DoubleCellValue(_r(studentK))],
      ['Actual k (hidden)',        DoubleCellValue(_r(actualK))],
      ['Percentage Error (%)',     DoubleCellValue(_r(pctError))],
      ['Min required trials',      const IntCellValue(3)],
      ['Max allowed trials',       const IntCellValue(12)],
    ];

    for (int i = 0; i < summaryRows.length; i++) {
      final row = summaryStart + i;
      _set(sheet, row, 0, TextCellValue(summaryRows[i][0] as String), labelStyle);
      _set(sheet, row, 1, summaryRows[i][1] as CellValue, valueStyle);
    }

    // ── Column widths ──────────────────────────────────────────────────────────
    final widths = [8.0, 14.0, 14.0, 10.0, 12.0, 12.0, 14.0, 14.0,
                    10.0, 10.0, 10.0, 14.0, 14.0, 16.0, 16.0, 22.0, 26.0];
    for (int c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  SHEET 2  —  Graph Data
  // ════════════════════════════════════════════════════════════════════════════

  static void _buildGraphDataSheet(
    Excel excel,
    List<TrialModel> trials,
  ) {
    final sheet = excel['Graph Data'];

    // ── Title ──────────────────────────────────────────────────────────────────
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: _deepBlue,
    );
    _set(sheet, 0, 0,
        TextCellValue('Graph Data — τ vs Y for Graphical k Determination'),
        titleStyle);
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0),
    );

    // ── Header row ─────────────────────────────────────────────────────────────
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: _deepBlue,
      fontColorHex: _white,
      horizontalAlign: HorizontalAlign.Center,
    );
    for (int c = 0; c < _graphHeaders.length; c++) {
      _set(sheet, 2, c, TextCellValue(_graphHeaders[c]), headerStyle);
    }

    // ── Data rows ──────────────────────────────────────────────────────────────
    for (int i = 0; i < trials.length; i++) {
      final t   = trials[i];
      final row = i + 3;
      final bg  = i.isEven ? _white : _lightGrey;
      final style = CellStyle(
        backgroundColorHex: bg,
        horizontalAlign: HorizontalAlign.Center,
      );
      _set(sheet, row, 0, DoubleCellValue(_r(t.tau)),    style);
      _set(sheet, row, 1, DoubleCellValue(_r(t.graphY)), style);
    }

    // ── Note at bottom ─────────────────────────────────────────────────────────
    final noteRow = trials.length + 5;
    final noteStyle = CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString('FF757575'),
    );
    _set(
      sheet, noteRow, 0,
      TextCellValue(
          'Note: Plot Y vs τ — the line through the origin has '
          'slope = k, allowing graphical determination of k.'),
      noteStyle,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: noteRow),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: noteRow),
    );

    // ── Column widths ──────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 16.0);
    sheet.setColumnWidth(1, 26.0);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Writes a value and optional style to a cell identified by [row] + [col]
  /// (both 0-indexed).
  static void _set(
    Sheet sheet,
    int row,
    int col,
    CellValue value, [
    CellStyle? style,
  ]) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value;
    if (style != null) cell.cellStyle = style;
  }

  /// Rounds a double to 6 decimal places for consistent cell output.
  static double _r(double v) => double.tryParse(v.toStringAsFixed(6)) ?? v;
}
