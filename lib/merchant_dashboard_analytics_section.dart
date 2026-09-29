part of 'merchant_dashboard.dart';

class _AnalyticsBucket {
  const _AnalyticsBucket({
    required this.key,
    required this.label,
    this.sales = 0,
    this.customers = 0,
    this.bookings = 0,
    this.participants = 0,
  });

  final String key;
  final String label;
  final double sales;
  final int customers;
  final int bookings;
  final int participants;
}

List<DateTime> _weekStarts(DateTime start, DateTime end) {
  final first = _weekStart(start);
  final last = _weekStart(end);
  final weeks = last.difference(first).inDays ~/ 7;
  return [
    for (var offset = 0; offset <= weeks; offset++)
      first.add(Duration(days: offset * 7)),
  ];
}

DateTime _weekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

class _VenueAnalytics {
  const _VenueAnalytics({
    required this.name,
    required this.bookings,
    required this.participants,
    required this.sales,
    required this.rating,
    required this.reviewCount,
  });

  final String name;
  final int bookings;
  final int participants;
  final double sales;
  final double rating;
  final int reviewCount;
}

extension _MerchantDashboardAnalyticsSection on _MerchantDashboardPageState {
  Widget _merchantAnalyticsDashboard() => RefreshIndicator(
    onRefresh: () async {
      await _loadBusinesses();
      await _loadBookings();
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data analytics',
                    style: TextStyle(
                      color: _merchantInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Track sales, customers, and venue performance.',
                    style: TextStyle(color: _merchantMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('merchant-analytics-date-filter'),
              onPressed: _chooseAnalyticsDateRange,
              icon: const Icon(Icons.calendar_month_outlined, size: 17),
              label: Text(
                _analyticsDateRange == null
                    ? 'Date range'
                    : _analyticsDateRangeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _merchantNavy,
                side: const BorderSide(color: _merchantLine),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _analyticsViewSelector,
        const SizedBox(height: 12),
        SegmentedButton<String>(
          key: const ValueKey('merchant-analytics-period'),
          segments: const [
            ButtonSegment(value: 'Daily', label: Text('Daily')),
            ButtonSegment(value: 'Weekly', label: Text('Weekly')),
            ButtonSegment(value: 'Monthly', label: Text('Monthly')),
            ButtonSegment(value: 'Annual', label: Text('Annual')),
          ],
          selected: {_analyticsPeriod},
          onSelectionChanged: (selection) {
            _setAnalyticsState(() => _analyticsPeriod = selection.first);
          },
        ),
        const SizedBox(height: 12),
        _analyticsSummaryCard,
        const SizedBox(height: 12),
        _analyticsChartCard,
        if (_analyticsView == 'Venue performance') ...[
          const SizedBox(height: 12),
          _analyticsVenueCard,
        ],
        const SizedBox(height: 12),
        _analyticsBookingStatusCard,
      ],
    ),
  );

  Widget get _analyticsViewSelector {
    const views = [
      ('Sales report', Icons.show_chart_rounded),
      ('Customer count', Icons.people_outline_rounded),
      ('Venue performance', Icons.storefront_outlined),
    ];
    return Row(
      children: [
        for (var index = 0; index < views.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _AnalyticsViewTile(
              key: ValueKey('merchant-analytics-view-${views[index].$1}'),
              title: views[index].$1,
              icon: views[index].$2,
              selected: _analyticsView == views[index].$1,
              onTap: () =>
                  _setAnalyticsState(() => _analyticsView = views[index].$1),
            ),
          ),
        ],
      ],
    );
  }

  String get _analyticsDateRangeLabel {
    final range = _analyticsDateRange;
    if (range == null) return 'Date range';
    return '${_shortDate(range.start)} - ${_shortDate(range.end)}';
  }

  String _shortDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year.toString().substring(2)}';

  Future<void> _chooseAnalyticsDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _analyticsDateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (range != null && mounted) {
      _setAnalyticsState(() => _analyticsDateRange = range);
    }
  }

  List<_AnalyticsBucket> get _analyticsBuckets {
    final now = DateTime.now();
    final range = _analyticsDateRange;
    final starts = switch (_analyticsPeriod) {
      'Weekly' => _weekStarts(
        range?.start ?? now.subtract(const Duration(days: 77)),
        range?.end ?? now,
      ),
      'Monthly' => _monthStarts(
        range?.start ?? DateTime(now.year, now.month - 11, 1),
        range?.end ?? now,
      ),
      'Annual' => _yearStarts(
        range?.start ?? DateTime(now.year - 4, 1, 1),
        range?.end ?? now,
      ),
      _ => _dayStarts(
        range?.start ?? now.subtract(const Duration(days: 6)),
        range?.end ?? now,
      ),
    };
    final sales = List<double>.filled(starts.length, 0);
    final customersByBucket = List<Set<String>>.generate(
      starts.length,
      (_) => <String>{},
    );
    final bookingCounts = List<int>.filled(starts.length, 0);
    final participantCounts = List<int>.filled(starts.length, 0);
    final keys = starts.map(_analyticsKey).toList();
    for (final booking in _bookings) {
      if (_isCancelledBooking(booking)) continue;
      final date = _bookingDate(booking);
      if (date == null) continue;
      if (range != null &&
          (date.isBefore(
                DateTime(range.start.year, range.start.month, range.start.day),
              ) ||
              date.isAfter(
                DateTime(
                  range.end.year,
                  range.end.month,
                  range.end.day,
                  23,
                  59,
                  59,
                ),
              ))) {
        continue;
      }
      final index = keys.indexOf(_analyticsKeyForDate(date));
      if (index < 0) continue;
      bookingCounts[index]++;
      participantCounts[index] += _bookingCount(booking['players']);
      final customerId = booking['customerId'] ?? booking['customerName'];
      if (customerId != null) customersByBucket[index].add('$customerId');
      if (_isConfirmedBooking(booking)) {
        sales[index] += _bookingAmount(booking['total']);
      }
    }
    return [
      for (var index = 0; index < starts.length; index++)
        _AnalyticsBucket(
          key: keys[index],
          label: switch (_analyticsPeriod) {
            'Weekly' =>
              '${_monthLabel(starts[index].month)} ${starts[index].day}',
            'Monthly' => _monthLabel(starts[index].month),
            'Annual' => '${starts[index].year}',
            _ => _weekdayLabel(starts[index].weekday),
          },
          sales: sales[index],
          customers: customersByBucket[index].length,
          bookings: bookingCounts[index],
          participants: participantCounts[index],
        ),
    ];
  }

  List<DateTime> _dayStarts(DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    final days = last.difference(first).inDays;
    return [
      for (var offset = 0; offset <= days; offset++)
        first.add(Duration(days: offset)),
    ];
  }

  List<DateTime> _monthStarts(DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);
    final months = (last.year - first.year) * 12 + last.month - first.month;
    return [
      for (var offset = 0; offset <= months; offset++)
        DateTime(first.year, first.month + offset, 1),
    ];
  }

  List<DateTime> _yearStarts(DateTime start, DateTime end) => [
    for (var year = start.year; year <= end.year; year++) DateTime(year, 1, 1),
  ];

  DateTime? _bookingDate(Map<String, dynamic> booking) {
    final value = booking['date'] ?? booking['bookingDate'];
    if (value is DateTime) return value;
    return DateTime.tryParse('$value');
  }

  String _analyticsKey(DateTime date) => switch (_analyticsPeriod) {
    'Weekly' => _calendarDateKey(_weekStart(date)),
    'Monthly' => '${date.year}-${date.month.toString().padLeft(2, '0')}',
    'Annual' => '${date.year}',
    _ =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
  };

  String _analyticsKeyForDate(DateTime date) => _analyticsKey(date);

  String _calendarDateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _monthLabel(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  String _weekdayLabel(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  bool _isConfirmedBooking(Map<String, dynamic> booking) {
    final status = '${booking['status'] ?? ''}'.toLowerCase();
    return status == 'approved' || status == 'finished';
  }

  bool _isCancelledBooking(Map<String, dynamic> booking) =>
      '${booking['status'] ?? ''}'.toLowerCase() == 'cancelled';

  List<Map<String, dynamic>> get _periodBookings {
    final bucketKeys = _analyticsBuckets.map((bucket) => bucket.key).toSet();
    return _bookings.where((booking) {
      if (_isCancelledBooking(booking)) return false;
      final date = _bookingDate(booking);
      if (date == null || !bucketKeys.contains(_analyticsKeyForDate(date))) {
        return false;
      }
      final range = _analyticsDateRange;
      if (range == null) return true;
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  double get _periodSales => _periodBookings
      .where(_isConfirmedBooking)
      .fold(0, (total, booking) => total + _bookingAmount(booking['total']));

  double get _periodCollected => _periodBookings
      .where(_isConfirmedBooking)
      .fold(
        0,
        (total, booking) => total + _bookingAmount(booking['downpayment']),
      );

  int get _periodCustomers => _periodBookings
      .map((booking) => booking['customerId'] ?? booking['customerName'])
      .where((customer) => customer != null)
      .map((customer) => '$customer')
      .toSet()
      .length;

  int get _periodParticipants => _periodBookings.fold(
    0,
    (total, booking) => total + _bookingCount(booking['players']),
  );

  int _bookingCount(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  int get _pendingBookingCount => _bookings
      .where((booking) => '${booking['status']}'.toLowerCase() == 'pending')
      .length;

  Widget get _analyticsSummaryCard {
    final liveVenues = _businesses.where(_isLiveOnApp).length;
    final primaryMetric = switch (_analyticsView) {
      'Customer count' => '$_periodParticipants',
      'Venue performance' => '${_periodBookings.length}',
      _ => _formatCurrency(_periodSales),
    };
    final primaryLabel = switch (_analyticsView) {
      'Customer count' => 'Players',
      'Venue performance' => 'Bookings in range',
      _ => 'Confirmed sales',
    };
    final primaryIcon = switch (_analyticsView) {
      'Customer count' => Icons.people_outline_rounded,
      'Venue performance' => Icons.storefront_outlined,
      _ => Icons.trending_up_rounded,
    };
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _analyticsMetric(primaryLabel, primaryMetric, primaryIcon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _analyticsMetric(
                _analyticsView == 'Customer count' ? 'Customers' : 'Collected',
                _analyticsView == 'Customer count'
                    ? '$_periodCustomers'
                    : _formatCurrency(_periodCollected),
                _analyticsView == 'Customer count'
                    ? Icons.person_outline_rounded
                    : Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _analyticsMetric(
                'Bookings',
                '${_periodBookings.length}',
                Icons.event_available_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _analyticsMetric(
                'Live venues',
                '$liveVenues / ${_businesses.length}',
                Icons.storefront_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _analyticsMetric(String label, String value, IconData icon) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: _merchantOrange, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _merchantMuted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _merchantInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget get _analyticsChartCard {
    final buckets = _analyticsBuckets;
    final venues = _venueAnalytics;
    final isVenueView = _analyticsView == 'Venue performance';
    final isCustomerView = _analyticsView == 'Customer count';
    final values = isVenueView
        ? venues.map((venue) => venue.bookings.toDouble()).toList()
        : isCustomerView
        ? buckets.map((bucket) => bucket.participants.toDouble()).toList()
        : buckets.map((bucket) => bucket.sales).toList();
    final labels = isVenueView
        ? venues.map((venue) => venue.name).toList()
        : buckets.map((bucket) => bucket.label).toList();
    final chartWidth = math
        .max(MediaQuery.sizeOf(context).width - 62, values.length * 46.0)
        .toDouble();
    final chartTitle = switch (_analyticsView) {
      'Customer count' => 'Players by $_analyticsPeriod',
      'Venue performance' => 'Bookings by venue',
      _ => 'Sales report · $_analyticsPeriod',
    };
    final chartSummary = switch (_analyticsView) {
      'Customer count' =>
        '$_periodParticipants players across $_periodCustomers '
            'customer${_periodCustomers == 1 ? '' : 's'}',
      'Venue performance' =>
        '${_periodBookings.length} bookings across your venues',
      _ =>
        '${_formatCurrency(_periodSales)} confirmed sales · '
            '${_formatCurrency(_periodCollected)} collected',
    };
    return _analyticsPanel(
      title: chartTitle,
      subtitle: isVenueView
          ? 'Sort by confirmed sales and booking volume'
          : isCustomerView
          ? 'Each point shows booked players for one ${_analyticsPeriod.toLowerCase()}'
          : 'Bookings grouped by ${_analyticsPeriod.toLowerCase()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('merchant-analytics-chart-full-view'),
              onPressed: () => _openAnalyticsChartFullView(
                title: chartTitle,
                subtitle: isCustomerView
                    ? 'Players booked in each ${_analyticsPeriod.toLowerCase()}'
                    : isVenueView
                    ? 'Bookings for each venue'
                    : 'Sales grouped by ${_analyticsPeriod.toLowerCase()}',
                values: values,
                labels: labels,
                valueColor: isCustomerView
                    ? const Color(0xFF168B69)
                    : _merchantOrange,
                formatValue: isVenueView || isCustomerView
                    ? (value) => value.round().toString()
                    : _compactCurrency,
                showDataLabels: isCustomerView,
                summary: chartSummary,
              ),
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const Text('Full view'),
            ),
          ),
          SizedBox(
            height: 190,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                key: isCustomerView
                    ? const ValueKey('merchant-analytics-player-chart')
                    : null,
                width: chartWidth,
                child: _AnalyticsLineChart(
                  values: values,
                  labels: labels,
                  valueColor: isCustomerView
                      ? const Color(0xFF168B69)
                      : _merchantOrange,
                  showDataLabels: isCustomerView,
                  formatValue: isVenueView || isCustomerView
                      ? (value) => value.round().toString()
                      : _compactCurrency,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _analyticsChartSummary(chartSummary),
        ],
      ),
    );
  }

  Future<void> _openAnalyticsChartFullView({
    required String title,
    required String subtitle,
    required List<double> values,
    required List<String> labels,
    required Color valueColor,
    required String Function(double value) formatValue,
    required bool showDataLabels,
    required String summary,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _AnalyticsFullChartPage(
        title: title,
        subtitle: subtitle,
        values: values,
        labels: labels,
        valueColor: valueColor,
        formatValue: formatValue,
        showDataLabels: showDataLabels,
        summary: summary,
      ),
    ),
  );

  Widget _analyticsChartSummary(String summary) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.summarize_outlined, color: _merchantNavy, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            summary,
            style: const TextStyle(
              color: _merchantNavy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  List<_VenueAnalytics> get _venueAnalytics {
    final stats = <String, ({int bookings, int participants, double sales})>{};
    for (final booking in _periodBookings) {
      final name = '${booking['venueName'] ?? 'Venue'}';
      final current = stats[name] ?? (bookings: 0, participants: 0, sales: 0);
      stats[name] = (
        bookings: current.bookings + 1,
        participants: current.participants + _bookingCount(booking['players']),
        sales:
            current.sales +
            (_isConfirmedBooking(booking)
                ? _bookingAmount(booking['total'])
                : 0),
      );
    }
    final names = <String>{
      ..._businesses.map((business) => '${business['name'] ?? 'Venue'}'),
      ...stats.keys,
    };
    final analytics = [
      for (final name in names)
        _VenueAnalytics(
          name: name,
          bookings: stats[name]?.bookings ?? 0,
          participants: stats[name]?.participants ?? 0,
          sales: stats[name]?.sales ?? 0,
          rating: _businessRating(name),
          reviewCount: _businessReviewCount(name),
        ),
    ];
    analytics.sort((a, b) {
      final salesCompare = b.sales.compareTo(a.sales);
      if (salesCompare != 0) return salesCompare;
      final bookingCompare = b.bookings.compareTo(a.bookings);
      return bookingCompare != 0
          ? bookingCompare
          : b.rating.compareTo(a.rating);
    });
    return analytics;
  }

  double _businessRating(String name) {
    for (final business in _businesses) {
      if ('${business['name'] ?? ''}' == name) {
        return _bookingAmount(
          business['averageRating'] ?? business['average_rating'],
        );
      }
    }
    return 0;
  }

  int _businessReviewCount(String name) {
    for (final business in _businesses) {
      if ('${business['name'] ?? ''}' == name) {
        final count = business['reviewCount'] ?? business['review_count'] ?? 0;
        return count is num ? count.toInt() : int.tryParse('$count') ?? 0;
      }
    }
    return 0;
  }

  Widget get _analyticsVenueCard {
    final ranked = _venueAnalytics;
    return _analyticsPanel(
      title: 'Venue performance',
      subtitle: 'Ratings, confirmed sales, and booking counts',
      child: ranked.isEmpty
          ? const Text(
              'Venue performance will appear when bookings come in.',
              style: TextStyle(color: _merchantMuted, fontSize: 13),
            )
          : Column(
              children: [
                for (final entry in ranked.take(5).toList().asMap().entries)
                  Padding(
                    padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFFFFE8D2),
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: _merchantNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _merchantInk,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${entry.value.bookings} bookings · '
                                '${entry.value.participants} players · '
                                '${entry.value.reviewCount} reviews',
                                style: const TextStyle(
                                  color: _merchantMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(entry.value.sales),
                              style: const TextStyle(
                                color: _merchantNavy,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              entry.value.rating > 0
                                  ? '★ ${entry.value.rating.toStringAsFixed(1)}'
                                  : 'No rating',
                              style: const TextStyle(
                                color: _merchantMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget get _analyticsBookingStatusCard {
    final confirmedCount = _bookings.where(_isConfirmedBooking).length;
    final finishedCount = _bookings
        .where((booking) => '${booking['status']}'.toLowerCase() == 'finished')
        .length;
    return _analyticsPanel(
      title: 'Bookings overview',
      subtitle: 'Current status across all venues',
      child: Row(
        children: [
          Expanded(child: _statusMetric('Pending', _pendingBookingCount)),
          Expanded(
            child: _statusMetric('Approved', confirmedCount - finishedCount),
          ),
          Expanded(child: _statusMetric('Finished', finishedCount)),
          Expanded(
            child: _statusMetric(
              'Cancelled',
              _bookings
                  .where(
                    (booking) =>
                        '${booking['status']}'.toLowerCase() == 'cancelled',
                  )
                  .length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusMetric(String label, int value) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(
          color: _merchantInk,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _merchantMuted, fontSize: 10),
      ),
    ],
  );

  Widget _analyticsPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: ValueKey(
              'merchant-analytics-panel-${title.toLowerCase().replaceAll(' ', '-')}',
            ),
            style: const TextStyle(
              color: _merchantInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: _merchantMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  String _formatCurrency(double value) => 'PHP ${value.toStringAsFixed(2)}';

  String _compactCurrency(double value) {
    if (value >= 1000000) return '₱${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '₱${(value / 1000).toStringAsFixed(1)}k';
    return '₱${value.round()}';
  }
}
