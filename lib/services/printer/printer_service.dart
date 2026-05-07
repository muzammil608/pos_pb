import 'package:flutter/material.dart';
import '../../widgets/receipt_dialog.dart';

class PrinterService {
  static Future<void> showReceiptDialog(
    BuildContext context,
    String orderId,
    List<Map<String, dynamic>> cartItems,
    double total, {
    String orderType = 'takeaway',
    String? tableNumber,
    String? customerName,
    String paymentMethod = 'cash',
    double tenderedAmount = 0.0,
    double change = 0.0,
    String servedBy = 'Staff',
  }) async {
    final grandTotal = total;
    final subtotal = grandTotal / 1.13;
    final tax = grandTotal - subtotal;
    final resolvedCustomerName =
        (customerName != null && customerName.trim().isNotEmpty)
            ? customerName.trim()
            : 'Walk-in Customer';
    final resolvedOrderType =
        orderType == 'dine_in' && tableNumber != null && tableNumber.isNotEmpty
            ? 'DINE IN - TABLE $tableNumber'
            : orderType.replaceAll('_', ' ').toUpperCase();
    final now = DateTime.now();
    final formattedDate =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    await showDialog(
      context: context,
      builder: (ctx) => ReceiptDialog(
        companyName: 'ORION PIZZA RESTAURANT',
        phone: '+92 3177921817',
        email: 'muzmalabbas579@gmail.com',
        website: 'www.orionpizza.com',
        servedBy: servedBy,
        customerName: resolvedCustomerName,
        orderType: resolvedOrderType,
        items: cartItems,
        total: grandTotal,
        cash: tenderedAmount,
        change: change,
        tax: tax,
        paymentMethod: paymentMethod,
        orderNo: orderId,
        date: formattedDate,
      ),
    );
  }
}
