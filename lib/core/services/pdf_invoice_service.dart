import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:goodwin/core/utils/product_image_resolver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:goodwin/models/order_model.dart';

class PdfInvoiceService {
  static const PdfColor _primaryTeal = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor _darkSlate = PdfColor.fromInt(0xFF111827);
  static const PdfColor _mutedSlate = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _borderSlate = PdfColor.fromInt(0xFFE5E7EB);

  static Future<Uint8List> generateInvoicePdf(OrderModel order) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final orderNo = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
    final totalUnits = order.items.fold<int>(0, (sum, i) => sum + i.quantity);

    // Pre-load product images for the PDF table
    final Map<String, pw.ImageProvider> itemImages = {};
    for (final item in order.items) {
      final imgUrl = resolveOrderItemImage(item);
      if (imgUrl.isNotEmpty && !itemImages.containsKey(item.productId)) {
        final img = await _loadPdfImage(imgUrl);
        if (img != null) {
          itemImages[item.productId] = img;
        }
      }
    }

    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      regularFont = await PdfGoogleFonts.robotoRegular();
      boldFont = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      // Graceful fallback for offline test environments
    }

    final theme = (regularFont != null && boldFont != null)
        ? pw.ThemeData.withFont(base: regularFont, bold: boldFont)
        : pw.ThemeData.base();

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: _primaryTeal,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'GOODWIN WHOLESALE',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'B2B Distribution Hub & Warehousing',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'TAX INVOICE / PO',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '#$orderNo',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Order & Customer Info Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: _lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: _borderSlate, width: 1),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Billed To Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILLED TO:',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _mutedSlate,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            order.customerName.isNotEmpty ? order.customerName : 'Reseller Buyer',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: _darkSlate,
                            ),
                          ),
                          if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Phone: ${order.customerPhone}',
                              style: const pw.TextStyle(fontSize: 10, color: _mutedSlate),
                            ),
                          ],
                          pw.SizedBox(height: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.amber100,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              '${order.customerTier.toUpperCase()} RESELLER TIER',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.amber900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Order Details Column
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date: ${dateFormat.format(order.createdAt)}',
                            style: const pw.TextStyle(fontSize: 10, color: _darkSlate),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Fulfillment: ${order.isOnlineOrder ? 'Prepaid Online Delivery' : 'Warehouse Pickup'}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _darkSlate),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Payment: ${order.paymentMethod.toUpperCase()} (${order.paymentStatus.name.toUpperCase()})',
                            style: const pw.TextStyle(fontSize: 9, color: _mutedSlate),
                          ),
                          if (order.pickupCode.isNotEmpty) ...[
                            pw.SizedBox(height: 6),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blue50,
                                borderRadius: pw.BorderRadius.circular(4),
                                border: pw.Border.all(color: _primaryTeal, width: 0.8),
                              ),
                              child: pw.Text(
                                'Pickup Code: ${order.pickupCode}',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _primaryTeal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Itemized Table
              pw.Text(
                'PURCHASED PRODUCTS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkSlate,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: const pw.BorderSide(color: _borderSlate, width: 0.5),
                  bottom: const pw.BorderSide(color: _borderSlate, width: 1),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(4.5),
                  1: pw.FlexColumnWidth(2.2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(2.3),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _lightBg),
                    children: [
                      _buildProductCell('Item Description', isHeader: true),
                      _buildTableCell('Variation / Pack', isHeader: true, align: pw.TextAlign.left),
                      _buildTableCell('Unit Price', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
                      _buildTableCell('Total (INR)', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Table Rows
                  ...order.items.map((item) {
                    final variantName = item.variant != null && item.variant!.isNotEmpty
                        ? item.variant!
                        : '-';
                    final img = itemImages[item.productId];
                    return pw.TableRow(
                      children: [
                        _buildProductCell(item.productName, image: img),
                        _buildTableCell(variantName, align: pw.TextAlign.left),
                        _buildTableCell('Rs. ${item.unitPrice.toStringAsFixed(0)}', align: pw.TextAlign.right),
                        _buildTableCell('${item.quantity}', align: pw.TextAlign.center),
                        _buildTableCell('Rs. ${item.totalPrice.toStringAsFixed(0)}', align: pw.TextAlign.right, isBold: true),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // Summary Box
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Terms & Notice
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _lightBg,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Important Information:',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkSlate),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '- Present this purchase receipt along with your Pickup Code at the warehouse counter.',
                            style: const pw.TextStyle(fontSize: 7.5, color: _mutedSlate),
                          ),
                          pw.Text(
                            '- All prices are inclusive of wholesale GST and warehouse handling charges.',
                            style: const pw.TextStyle(fontSize: 7.5, color: _mutedSlate),
                          ),
                          pw.Text(
                            '- For support or bulk logistics inquiries, contact Goodwin wholesale support.',
                            style: const pw.TextStyle(fontSize: 7.5, color: _mutedSlate),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Financial Breakdown
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _buildSummaryRow('Total Items:', '$totalUnits units'),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Subtotal:', 'Rs. ${order.totalAmount.toStringAsFixed(0)}'),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Taxes:', 'Included'),
                        pw.Divider(color: _borderSlate, thickness: 1),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Grand Total:',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _darkSlate),
                            ),
                            pw.Text(
                              'Rs. ${order.totalAmount.toStringAsFixed(0)}',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: _primaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer Note
              pw.Center(
                child: pw.Text(
                  'Thank you for partnering with Goodwin Wholesale & Distribution Platform.',
                  style: const pw.TextStyle(fontSize: 8, color: _mutedSlate),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 9,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? _mutedSlate : _darkSlate,
        ),
      ),
    );
  }

  static Future<pw.ImageProvider?> _loadPdfImage(String rawUrl) async {
    if (rawUrl.isEmpty) return null;
    try {
      if (rawUrl.startsWith('data:image')) {
        final commaIndex = rawUrl.indexOf(',');
        final base64Str = commaIndex != -1 ? rawUrl.substring(commaIndex + 1) : rawUrl;
        final bytes = base64Decode(base64Str);
        return pw.MemoryImage(bytes);
      }
      if (rawUrl.startsWith('assets/')) {
        final data = await rootBundle.load(rawUrl);
        return pw.MemoryImage(data.buffer.asUint8List());
      }
      return await networkImage(rawUrl);
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildProductCell(
    String productName, {
    pw.ImageProvider? image,
    bool isHeader = false,
  }) {
    if (isHeader) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        child: pw.Text(
          productName,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: _mutedSlate,
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (image != null)
            pw.Container(
              width: 26,
              height: 26,
              margin: const pw.EdgeInsets.only(right: 6),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: _borderSlate, width: 0.5),
              ),
              child: pw.ClipRRect(
                horizontalRadius: 4,
                verticalRadius: 4,
                child: pw.Image(
                  image,
                  width: 26,
                  height: 26,
                  fit: pw.BoxFit.cover,
                ),
              ),
            )
          else
            pw.Container(
              width: 26,
              height: 26,
              margin: const pw.EdgeInsets.only(right: 6),
              decoration: pw.BoxDecoration(
                color: _lightBg,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: _borderSlate, width: 0.5),
              ),
              child: pw.Center(
                child: pw.Text(
                  productName.isNotEmpty ? productName[0].toUpperCase() : 'P',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _mutedSlate,
                  ),
                ),
              ),
            ),
          pw.Expanded(
            child: pw.Text(
              productName,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _darkSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _mutedSlate)),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _darkSlate)),
      ],
    );
  }

  static Future<void> printInvoice(OrderModel order) async {
    final pdfBytes = await generateInvoicePdf(order);
    final orderNo = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_$orderNo.pdf',
    );
  }

  static Future<void> shareInvoice(OrderModel order) async {
    final pdfBytes = await generateInvoicePdf(order);
    final orderNo = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_$orderNo.pdf',
    );
  }
}
