// Synthetic values following the active Java reporting delegates, not customer
// data. Assignee snapshots intentionally leave name/contact unset.
const backendBookingRow = <String, Object?>{
  'bookingId': 41,
  'bookingDate': '2026-10-10',
  'finalAmount': 1000.50,
  'remainingAmountPaid': 750.50,
  'walletCreditUsed': 250,
  'paymentMode': null,
};

const backendOrderRow = <String, Object?>{
  'orderId': 7,
  'orderDate': '2026-10-10',
  'grandTotal': 125.25,
  'paymentMode': null,
};

const backendAssigneeRow = <String, Object?>{
  'bookingId': 41,
  'scheduledDate': '2026-10-10',
  'assigneeEmail': 'Synthetic Staff',
  'assigneeName': null,
  'contactNumber': null,
  'catalogServices': 'Synthetic Service',
  'servicePrice': 500.25,
};

Map<String, Object?> backendReport(List<Object?> rows) => {
  'version': 'v1',
  'columns': [
    {'key': 'bookingId', 'title': 'Booking ID', 'dataType': 'number'},
  ],
  'summaryMetrics': [
    {
      'key': 'bookingId',
      'label': 'Bookings',
      'operation': 'count',
      'formatter': 'number',
    },
  ],
  'rows': rows,
  'sections': null,
};
