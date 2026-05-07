import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptDialog extends StatelessWidget {
  final String companyName;
  final String phone;
  final String email;
  final String website;
  final String servedBy;
  final String customerName;
  final String orderType;
  final List<Map<String, dynamic>> items;
  final double total;
  final double cash;
  final double change;
  final double tax;
  final String paymentMethod;
  final String orderNo;
  final String date;

  const ReceiptDialog({
    super.key,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.website,
    required this.servedBy,
    required this.customerName,
    required this.orderType,
    required this.items,
    required this.total,
    required this.cash,
    required this.change,
    required this.tax,
    required this.paymentMethod,
    required this.orderNo,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: SingleChildScrollView(
          child: ReceiptWidget(
            companyName: companyName,
            phone: phone,
            email: email,
            website: website,
            servedBy: servedBy,
            customerName: customerName,
            orderType: orderType,
            items: items,
            total: total,
            cash: cash,
            change: change,
            tax: tax,
            paymentMethod: paymentMethod,
            orderNo: orderNo,
            date: date,
            onPrint: () => _printReceipt(context),
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? logoImage;

      try {
        final logoBytes = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }

      final subtotal = total - tax;

      const double pageWidth = 80.0 * PdfPageFormat.mm;
      const double pageMargin = 6.0 * PdfPageFormat.mm;
      const double pageHeight = 400.0 * PdfPageFormat.mm;

      pdf.addPage(
        pw.Page(
          pageFormat:
              PdfPageFormat(pageWidth, pageHeight, marginAll: pageMargin),
          clip: false,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (logoImage != null)
                  pw.Center(
                    child: pw.Image(
                      logoImage,
                      height: 48,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                if (logoImage != null) pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                    child: pw.Text('Tel: $phone',
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Center(
                    child: pw.Text(email,
                        style: const pw.TextStyle(fontSize: 10))),
                pw.Center(
                    child: pw.Text(website,
                        style: const pw.TextStyle(fontSize: 10))),
                pw.SizedBox(height: 8),
                pw.Divider(),
                _pdfInfoRow('Served by', servedBy),
                _pdfInfoRow('Customer', customerName),
                _pdfInfoRow('Order Type', orderType),
                _pdfInfoRow('Order', orderNo),
                _pdfInfoRow('Date', date),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        'ITEM',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'QTY',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'TOTAL',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                ...items.map(_pdfItemRow),
                pw.SizedBox(height: 8),
                pw.Divider(),
                _pdfAmountRow('Subtotal', subtotal),
                _pdfAmountRow('Tax', tax),
                _pdfAmountRow('TOTAL', total, isBold: true),
                pw.SizedBox(height: 8),
                if (paymentMethod == 'cash') ...[
                  _pdfAmountRow('Cash', cash),
                  _pdfAmountRow('CHANGE', change),
                ],
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text(
                    'Thank you for visiting us',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Powered by Orion Solutions Pakistan',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'receipt_$orderNo',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    }
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(5),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Text(
                '$label:',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfItemRow(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Item';
    final qty = (item['qty'] as num?)?.toInt() ??
        (item['quantity'] as num?)?.toInt() ??
        1;
    final unitPrice =
        ((item['unitPrice'] ?? item['price']) as num?)?.toDouble() ?? 0.0;
    final lineTotal = ((item['lineTotal']) as num?)?.toDouble() ??
        (qty * unitPrice).toDouble();

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            name,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Text(
                    'Rs ${unitPrice.toStringAsFixed(2)} each',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    '$qty',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    lineTotal.toStringAsFixed(2),
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfAmountRow(String label, double value, {bool isBold = false}) {
    final style = pw.TextStyle(
      fontSize: isBold ? 11 : 10,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Text(label, style: style),
              pw.Text(
                'Rs ${value.toStringAsFixed(2)}',
                textAlign: pw.TextAlign.right,
                style: style,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReceiptWidget extends StatelessWidget {
  final String companyName;
  final String phone;
  final String email;
  final String website;
  final String servedBy;
  final String customerName;
  final String orderType;
  final List<Map<String, dynamic>> items;
  final double total;
  final double cash;
  final double change;
  final double tax;
  final String paymentMethod;
  final String orderNo;
  final String date;
  final VoidCallback onPrint;
  final VoidCallback onClose;

  const ReceiptWidget({
    super.key,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.website,
    required this.servedBy,
    required this.customerName,
    required this.orderType,
    required this.items,
    required this.total,
    required this.cash,
    required this.change,
    required this.tax,
    required this.paymentMethod,
    required this.orderNo,
    required this.date,
    required this.onPrint,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = total - tax;

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              height: 54,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.store, size: 40);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            companyName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text('Tel: $phone', style: _metaStyle),
          Text(email, style: _metaStyle),
          Text(website, style: _metaStyle),
          const SizedBox(height: 8),
          const _ReceiptDivider(),
          const SizedBox(height: 8),
          _infoLine('Served by', servedBy),
          _infoLine('Customer', customerName),
          _infoLine('Order Type', orderType),
          _infoLine('Order', orderNo),
          _infoLine('Date', date),
          const SizedBox(height: 10),
          const _ReceiptDivider(),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(
                flex: 5,
                child: Text(
                  'ITEM',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'QTY',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'TOTAL',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _ReceiptItemRow(item: item)),
          const SizedBox(height: 10),
          const _ReceiptDivider(),
          const SizedBox(height: 10),
          _amountLine('Subtotal', subtotal),
          _amountLine('Tax', tax),
          const SizedBox(height: 4),
          _amountLine('TOTAL', total, isBold: true),
          const SizedBox(height: 12),
          if (paymentMethod == 'cash') ...[
            _amountLine('Cash', cash),
            _amountLine('CHANGE', change),
            const SizedBox(height: 12),
          ],
          Text(
            'Thank you for visiting us',
            textAlign: TextAlign.center,
            style: _metaStyle,
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by Orion Solutions Pakistan',
            textAlign: TextAlign.center,
            style: _metaStyle,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black26),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label:',
              style: _metaStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _metaStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountLine(String label, double value, {bool isBold = false}) {
    final style = TextStyle(
      fontSize: isBold ? 13 : 12,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('Rs ${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _ReceiptItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ReceiptItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Item';
    final qty = (item['qty'] as num?)?.toInt() ??
        (item['quantity'] as num?)?.toInt() ??
        1;
    final unitPrice =
        ((item['unitPrice'] ?? item['price']) as num?)?.toDouble() ?? 0.0;
    final lineTotal = ((item['lineTotal']) as num?)?.toDouble() ??
        (qty * unitPrice).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'Rs ${unitPrice.toStringAsFixed(2)} each',
                  style: _metaStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: _metaStyle,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  lineTotal.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: _metaStyle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 8).floor();
        return Text(
          List.filled(dashCount, '-').join(),
          style: _metaStyle.copyWith(letterSpacing: 1.2),
          maxLines: 1,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}

const TextStyle _metaStyle = TextStyle(
  fontSize: 11.5,
  color: Colors.black87,
  height: 1.3,
);
