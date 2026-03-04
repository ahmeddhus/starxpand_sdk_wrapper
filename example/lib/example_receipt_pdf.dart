import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Returns the receipt as a PDF.
// IMPORTANT: DESIGN MUST COPY AS CLOSLY AS POSSIBLE FROM PRINT_RECEIPT.DART FILE.
Future<Uint8List> generateExampleReceiptPdf({
  required BuildContext context,
  bool isDigitalDesign =
      false, // If set to true, it'll add a margin horizontally just to look better
}) async {
  final pdf = pw.Document();

  // Match these to them_text_scheme.dart
  pw.TextStyle headlineSmall = pw.TextStyle(fontSize: 20);
  pw.TextStyle bodySmall = pw.TextStyle(fontSize: 12);
  pw.TextStyle bodySmallBold = pw.TextStyle(fontSize: 12);

  List<SaleItem> saleItems = [
    SaleItem(name: "Item 1", quantity: 1, price: 20.00),
    SaleItem(name: "Item 2", quantity: 2, price: 15.50),
    SaleItem(name: "Item 3", quantity: 1, price: 30.00),
    SaleItem(name: "Item 4", quantity: 3, price: 10.00),
  ];

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        300, // width in points
        double.infinity,
        marginTop: 20,
        marginBottom: 20,
        marginLeft: 20,
        marginRight: 20,
      ),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            // Store address
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                "123 Broad Street, London, UK",
                style: bodySmall.copyWith(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ),

            // Header text
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                "Thanks for shopping at Our Store!",
                style: bodySmall.copyWith(fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
            ),

            // Total receipt value
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text(
                            "TOTAL",
                            style: bodySmall,
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.Text(
                            "£156.99",
                            style: headlineSmall,
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            pw.SizedBox(height: 20),

            // Item list
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Items", style: bodySmallBold, textAlign: pw.TextAlign.center),
                pw.Text("Price", style: bodySmallBold, textAlign: pw.TextAlign.center),
              ],
            ),

            pw.Divider(height: 1, color: PdfColors.black),

            pw.SizedBox(height: 10),

            // Sale items
            pw.ListView.builder(
              itemCount: saleItems.length,
              itemBuilder: (context, index) {
                SaleItem saleItem = saleItems[index];
                return pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.ConstrainedBox(
                    constraints: const pw.BoxConstraints(maxWidth: 500),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                // Title
                                pw.Text(
                                  saleItem.name,
                                  style: bodySmall,
                                  textAlign: pw.TextAlign.start,
                                ),
                              ],
                            ),
                          ),

                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                // Sale price
                                pw.Text("£${saleItem.price}", style: bodySmallBold),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            pw.SizedBox(height: 20),

            // Total value
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("TOTAL", style: bodySmallBold, textAlign: pw.TextAlign.center),
                pw.Text("£80.00", style: bodySmallBold, textAlign: pw.TextAlign.center),
              ],
            ),

            pw.SizedBox(height: 5),

            pw.Divider(height: 2, color: PdfColors.black),

            pw.SizedBox(height: 5),

            // Amount paid by cash
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "CASH",
                  style: bodySmall.copyWith(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  "£30.00",
                  style: bodySmall.copyWith(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),

            // Amount paid by card
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "CARD",
                  style: bodySmall.copyWith(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  "£50.00",
                  style: bodySmall.copyWith(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Sale date
            pw.Text("25/04/2024 14:33", style: bodySmallBold),
          ],
        );
      },
    ),
  );

  // Save and return the PDF file as Uint8List
  return pdf.save();
}

class SaleItem {
  final String name;
  final int quantity;
  final double price;

  SaleItem({required this.name, required this.quantity, required this.price});
}
