import 'package:excel/excel.dart';
import 'dart:io';

void main() {
  final excel = Excel.createExcel();
  
  final sheet = excel['Trial Data'];
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Hello');
  
  excel.setDefaultSheet('Trial Data');
  
  if (excel.sheets.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }

  final bytes = excel.save();
  if (bytes != null) {
      File('test2.xlsx').writeAsBytesSync(bytes);
  }
}
