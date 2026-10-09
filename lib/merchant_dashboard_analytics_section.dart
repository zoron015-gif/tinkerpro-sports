part of 'merchant_dashboard.dart';

const double _analyticsElementGap = 6;

const _analyticsFilterStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(40)),
  padding: WidgetStatePropertyAll(AppSpacing.buttonPadding),
  textStyle: WidgetStatePropertyAll(
    TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
  ),
  visualDensity: VisualDensity.standard,
);

class _AnalyticsBucket {
  const _AnalyticsBucket({
    required this.key,
    required this.label,
    this.sales = 0,
    this.collected = 0,
    this.customers = 0,
    this.bookings = 0,
    this.confirmedBookings = 0,
    this.participants = 0,
  });

  final String key;
  final String label;
  final double sales;
  final double collected;
  final int customers;
  final int bookings;
  final int confirmedBookings;
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
  String _bookingBusinessType(Map<String, dynamic> booking) =>
      '${booking['businessType'] ?? booking['business_type'] ?? ''}'.trim();

  double _bookingAmountReceived(Map<String, dynamic> booking) {
    final paymentStatus = '${booking['paymentStatus'] ?? ''}'.toLowerCase();
    if (paymentStatus != 'paid') return 0;
    return _bookingAmount(booking['total']);
  }

  List<String> get _analyticsBookingTypes {
    final types =
        _bookings
            .map(_bookingBusinessType)
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return types;
  }

  List<Map<String, dynamic>> get _analyticsBookings {
    if (_analyticsBookingType == 'All') return _bookings;
    return _bookings
        .where(
          (booking) =>
              _bookingBusinessType(booking).toLowerCase() ==
              _analyticsBookingType.toLowerCase(),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _analyticsBusinesses {
    if (_analyticsBookingType == 'All') return _businesses;
    return _businesses.where((business) {
      final type =
          '${business['businessType'] ?? business['business_type'] ?? ''}'
              .trim();
      return type.toLowerCase() == _analyticsBookingType.toLowerCase();
    }).toList();
  }

  Widget get _analyticsBookingTypeFilter => DropdownButtonFormField<String>(
    key: const ValueKey('merchant-analytics-booking-type-filter'),
    initialValue: _analyticsBookingType,
    isExpanded: true,
    style: TextStyle(
      color: _merchantInk,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    iconSize: 18,
    decoration: InputDecoration(
      labelText: appLanguageText('Booking type', 'Booking type'),
      prefixIcon: Icon(Icons.filter_list_rounded, size: 18),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      constraints: BoxConstraints(minHeight: 48),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantOrange, width: 1.5),
      ),
    ),
    items: [
      const DropdownMenuItem(
        value: 'All',
        child: AppText('All booking types', maxLines: 1, localize: true),
      ),
      for (final type in _analyticsBookingTypes)
        DropdownMenuItem(value: type, child: AppText(type, maxLines: 1)),
    ],
    onChanged: (value) {
      if (value != null) {
        _setAnalyticsState(() => _analyticsBookingType = value);
      }
    },
  );

  Widget _merchantAnalyticsDashboard() => RefreshIndicator(
    onRefresh: () async {
      await _loadBusinesses();
      await _loadBookings();
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _merchantActionCenter,
        const SizedBox(height: _analyticsElementGap),
        Row(
          children: [
            AppText(
              'Data analytics',
              style: TextStyle(
                color: _merchantInk,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
              localize: true,
            ),
            IconButton(
              key: const ValueKey('merchant-analytics-info'),
              tooltip: appLanguageText(
                'About data analytics',
                'About data analytics',
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const AppText('Data analytics', localize: true),
                  content: const AppText(
                    'Track sales, customers, and venue performance.',
                    localize: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const AppText('Got it', localize: true),
                    ),
                  ],
                ),
              ),
              icon: Icon(
                Icons.info_outline_rounded,
                color: _merchantMuted,
                size: 19,
              ),
              visualDensity: VisualDensity.compact,
              padding: AppSpacing.buttonPadding,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            ),
            const Spacer(),
            OutlinedButton.icon(
              key: const ValueKey('merchant-analytics-date-filter'),
              onPressed: _chooseAnalyticsDateRange,
              icon: const Icon(Icons.calendar_month_outlined, size: 17),
              label: AppText(
                _analyticsDateRange == null
                    ? 'Date range'
                    : _analyticsDateRangeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _merchantNavy,
                side: BorderSide(color: _merchantLine),
                minimumSize: const Size(0, 40),
                padding: AppSpacing.buttonPadding,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _analyticsElementGap),
        _analyticsViewSelector,
        const SizedBox(height: _analyticsElementGap),
        _analyticsBookingTypeFilter,
        const SizedBox(height: _analyticsElementGap),
        SegmentedButton<String>(
          key: const ValueKey('merchant-analytics-period'),
          style: _analyticsFilterStyle,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 'Daily',
              label: AppText('Daily', localize: true),
            ),
            ButtonSegment(
              value: 'Weekly',
              label: AppText('Weekly', localize: true),
            ),
            ButtonSegment(
              value: 'Monthly',
              label: AppText('Monthly', localize: true),
            ),
            ButtonSegment(
              value: 'Annual',
              label: AppText('Annual', localize: true),
            ),
          ],
          selected: {_analyticsPeriod},
          onSelectionChanged: (selection) {
            _setAnalyticsState(() => _analyticsPeriod = selection.first);
          },
        ),
        const SizedBox(height: _analyticsElementGap),
        _analyticsSummaryCard,
        const SizedBox(height: _analyticsElementGap),
        _analyticsChartCard,
        const SizedBox(height: _analyticsElementGap),
        _analyticsPopularServicesCard,
        if (_analyticsView == 'Venue performance') ...[
          const SizedBox(height: _analyticsElementGap),
          _analyticsVenueCard,
        ],
        const SizedBox(height: _analyticsElementGap),
        _analyticsBookingStatusCard,
      ],
    ),
  );

  Widget get _merchantActionCenter {
    final pendingCount = _bookings.where(_isPendingBooking).length;
    if (pendingCount == 0) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('merchant-action-center'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _merchantLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A192B50),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: _merchantOrange, size: 20),
              const SizedBox(width: _analyticsElementGap),
              Expanded(
                child: AppText(
                  'Needs your attention',
                  style: TextStyle(
                    color: _merchantInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  localize: true,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.softStatus,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText(
                  '$pendingCount pending',
                  key: const ValueKey('merchant-action-count'),
                  style: const TextStyle(
                    color: Color(0xFFB85C00),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: _analyticsElementGap),
          AppText(
            '$pendingCount booking${pendingCount == 1 ? '' : 's'} awaiting approval',
            style: TextStyle(color: _merchantMuted, fontSize: 13, height: 1.35),
            localize: true,
          ),
          const SizedBox(height: _analyticsElementGap),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('merchant-review-bookings'),
              onPressed: () {
                _setAnalyticsState(() {
                  _merchantTab = 3;
                  _payoutTab = 0;
                });
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const AppText('Review booking requests', localize: true),
              style: FilledButton.styleFrom(
                backgroundColor: _merchantNavy,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget get _analyticsViewSelector {
    const views = [
      ('Sales report', Icons.show_chart_rounded),
      ('Customer count', Icons.people_outline_rounded),
      ('Venue performance', Icons.storefront_outlined),
    ];
    return Row(
      children: [
        for (var index = 0; index < views.length; index++) ...[
          if (index > 0) const SizedBox(width: _analyticsElementGap),
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
    final collected = List<double>.filled(starts.length, 0);
    final customersByBucket = List<Set<String>>.generate(
      starts.length,
      (_) => <String>{},
    );
    final bookingCounts = List<int>.filled(starts.length, 0);
    final confirmedBookingCounts = List<int>.filled(starts.length, 0);
    final participantCounts = List<int>.filled(starts.length, 0);
    final keys = starts.map(_analyticsKey).toList();
    for (final booking in _analyticsBookings) {
      if (BookingStatusParser.isCancelled(booking['status'])) continue;
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
        collected[index] += _bookingAmountReceived(booking);
        confirmedBookingCounts[index]++;
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
          collected: collected[index],
          customers: customersByBucket[index].length,
          bookings: bookingCounts[index],
          confirmedBookings: confirmedBookingCounts[index],
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

  bool _isPendingBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.isPending(booking['status']);

  bool _isFinishedBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.parse(booking['status']) == BookingStatus.finished ||
      BookingStatusParser.parse(booking['status']) == BookingStatus.completed ||
      BookingStatusParser.parse(booking['status']) == BookingStatus.done;

  bool _isConfirmedBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.isConfirmed(booking['status']);

  List<Map<String, dynamic>> get _periodBookings {
    final bucketKeys = _analyticsBuckets.map((bucket) => bucket.key).toSet();
    return _analyticsBookings.where((booking) {
      if (BookingStatusParser.isCancelled(booking['status'])) return false;
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
      .fold(0, (total, booking) => total + _bookingAmountReceived(booking));

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

  Widget get _analyticsSummaryCard {
    final liveVenues = _analyticsBusinesses.where(_isLiveOnApp).length;
    final bookingCount = _periodBookings.length;
    final confirmedBookings = _periodBookings.where(_isConfirmedBooking).length;
    final pendingBookings = _periodBookings.where(_isPendingBooking).length;
    final collectedShare = _periodSales <= 0
        ? 0.0
        : (_periodCollected / _periodSales).clamp(0.0, 1.0);
    final liveVenueShare = _analyticsBusinesses.isEmpty
        ? 0.0
        : liveVenues / _analyticsBusinesses.length;
    final averagePlayers = bookingCount == 0
        ? 0.0
        : _periodParticipants / bookingCount;
    final primaryMetric = switch (_analyticsView) {
      'Customer count' => '$_periodParticipants',
      'Venue performance' => '$bookingCount',
      _ => _formatCurrency(_periodSales),
    };
    final primaryLabel = switch (_analyticsView) {
      'Customer count' => 'Players',
      'Venue performance' => 'Bookings in range',
      _ => 'Revenue',
    };
    final primaryContext = switch (_analyticsView) {
      'Customer count' =>
        '${averagePlayers.toStringAsFixed(1)} players per booking on average',
      'Venue performance' =>
        '$confirmedBookings confirmed · $pendingBookings pending',
      _ => '${(collectedShare * 100).round()}% collected',
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
              child: _analyticsMetric(
                primaryLabel,
                primaryMetric,
                primaryIcon,
                context: primaryContext,
                progress: switch (_analyticsView) {
                  'Customer count' => null,
                  'Venue performance' =>
                    bookingCount == 0 ? 0 : confirmedBookings / bookingCount,
                  _ => collectedShare,
                },
                progressLabel: switch (_analyticsView) {
                  'Venue performance' => 'Confirmed',
                  _ => 'Collected',
                },
                onTap: () => _selectAnalyticsView(
                  _analyticsView == 'Customer count'
                      ? 'Customer count'
                      : 'Sales report',
                ),
              ),
            ),
            const SizedBox(width: _analyticsElementGap),
            Expanded(
              child: _analyticsMetric(
                _analyticsView == 'Customer count' ? 'Customers' : 'Collected',
                _analyticsView == 'Customer count'
                    ? '$_periodCustomers'
                    : _formatCurrency(_periodCollected),
                _analyticsView == 'Customer count'
                    ? Icons.person_outline_rounded
                    : Icons.account_balance_wallet_outlined,
                context: _analyticsView == 'Customer count'
                    ? 'Unique customers in this period'
                    : 'Of ${_formatCurrency(_periodSales)} in confirmed sales',
                progress: _analyticsView == 'Customer count'
                    ? null
                    : collectedShare,
                progressLabel: 'Collected',
                onTap: () => _selectAnalyticsView(
                  _analyticsView == 'Customer count'
                      ? 'Customer count'
                      : 'Sales report',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _analyticsElementGap),
        Row(
          children: [
            Expanded(
              child: _analyticsMetric(
                'Bookings',
                '$bookingCount',
                Icons.event_available_outlined,
                context:
                    '$confirmedBookings confirmed · $pendingBookings pending',
                progress: bookingCount == 0
                    ? 0
                    : confirmedBookings / bookingCount,
                progressLabel: 'Confirmed',
                onTap: () => _selectAnalyticsView('Venue performance'),
              ),
            ),
            const SizedBox(width: _analyticsElementGap),
            Expanded(
              child: _analyticsMetric(
                'Live venues',
                '$liveVenues / ${_analyticsBusinesses.length}',
                Icons.storefront_outlined,
                context:
                    '${(liveVenueShare * 100).round()}% of your venues are live',
                progress: liveVenueShare,
                progressLabel: 'Live',
                onTap: () => _selectAnalyticsView('Venue performance'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _selectAnalyticsView(String view) {
    if (_analyticsView == view) return;
    _setAnalyticsState(() => _analyticsView = view);
  }

  Widget _analyticsMetric(
    String label,
    String value,
    IconData icon, {
    required String context,
    required VoidCallback onTap,
    double? progress,
    String? progressLabel,
  }) {
    final key = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return Card(
      key: ValueKey('merchant-analytics-metric-$key'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _merchantOrange, size: 21),
              const SizedBox(width: _analyticsElementGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _merchantMuted, fontSize: 11),
                    ),
                    const SizedBox(height: _analyticsElementGap),
                    AppText(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _merchantInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      context,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _merchantMuted,
                        fontSize: 10,
                        height: 1.2,
                      ),
                      localize: true,
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: _merchantLine,
                          color: _merchantOrange,
                          semanticsLabel: progressLabel,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _analyticsPopularServicesCard {
    final serviceCounts = <String, int>{};
    for (final booking in _periodBookings) {
      if (BookingStatusParser.isCancelled(booking['status'])) continue;
      final service = _bookingServiceLabel(booking).trim();
      if (service.isEmpty) continue;
      serviceCounts.update(service, (count) => count + 1, ifAbsent: () => 1);
    }
    final rankedServices = serviceCounts.entries.toList()
      ..sort((a, b) {
        final countOrder = b.value.compareTo(a.value);
        return countOrder != 0
            ? countOrder
            : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    final topServices = rankedServices.take(5).toList();
    final highestCount = topServices.isEmpty ? 1 : topServices.first.value;

    return _analyticsPanel(
      title: 'Popular services',
      subtitle: 'Most booked services in the selected period',
      child: topServices.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: AppText(
                'No service bookings in this period.',
                localize: true,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < topServices.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              topServices[index].key,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _merchantInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: topServices[index].value / highestCount,
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(8),
                              backgroundColor: _merchantLine,
                              color: _merchantOrange,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppText(
                        '${topServices[index].value} bookings',
                        style: TextStyle(
                          color: _merchantMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        localize: true,
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget get _analyticsChartCard {
    if (_analyticsView == 'Venue performance') {
      return _analyticsVenueComparisonChart;
    }
    final buckets = _analyticsBuckets;
    final isCustomerView = _analyticsView == 'Customer count';
    final venueSeries = isCustomerView
        ? _venueCustomerSeries
        : const <_AnalyticsChartSeries>[];
    final values = isCustomerView
        ? buckets.map((bucket) => bucket.customers.toDouble()).toList()
        : buckets.map((bucket) => bucket.sales).toList();
    final labels = buckets.map((bucket) => bucket.label).toList();
    final detailLabels = buckets
        .map((bucket) => '${bucket.label} · ${bucket.key}')
        .toList();
    final pointDetails = [
      for (final bucket in buckets)
        [
          _AnalyticsPointMetric(
            label: 'Confirmed sales',
            value: _formatCurrency(bucket.sales),
            color: _merchantOrange,
          ),
          _AnalyticsPointMetric(
            label: 'Collected payments',
            value: _formatCurrency(bucket.collected),
            color: const Color(0xFF168B69),
          ),
          _AnalyticsPointMetric(
            label: 'Bookings',
            value: '${bucket.bookings}',
            color: _merchantNavy,
          ),
          _AnalyticsPointMetric(
            label: 'Confirmed bookings',
            value: '${bucket.confirmedBookings}',
            color: _merchantMuted,
          ),
          _AnalyticsPointMetric(
            label: 'Players',
            value: '${bucket.participants}',
            color: const Color(0xFF5169C4),
          ),
          _AnalyticsPointMetric(
            label: 'Unique customers',
            value: '${bucket.customers}',
            color: const Color(0xFFB34E91),
          ),
          _AnalyticsPointMetric(
            label: 'Avg. confirmed booking',
            value: _formatCurrency(
              bucket.confirmedBookings == 0
                  ? 0
                  : bucket.sales / bucket.confirmedBookings,
            ),
            color: const Color(0xFFAB6D19),
          ),
        ],
    ];
    final chartWidth = math.max(280.0, values.length * 56.0).toDouble();
    final chartTitle = switch (_analyticsView) {
      'Customer count' => 'Customers by $_analyticsPeriod',
      _ => 'Sales report · $_analyticsPeriod',
    };
    final chartSummary = switch (_analyticsView) {
      'Customer count' => '$_periodCustomers unique customers across venues',
      _ =>
        '${_formatCurrency(_periodSales)} confirmed sales · '
            '${_formatCurrency(_periodCollected)} collected',
    };
    return _analyticsPanel(
      title: chartTitle,
      subtitle: isCustomerView
          ? 'Each line shows unique customers per venue for each ${_analyticsPeriod.toLowerCase()}'
          : 'Bookings grouped by ${_analyticsPeriod.toLowerCase()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (venueSeries.isNotEmpty) ...[
            _AnalyticsChartLegend(series: venueSeries),
            const SizedBox(height: _analyticsElementGap),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('merchant-analytics-chart-full-view'),
              onPressed: () => _openAnalyticsChartFullView(
                title: chartTitle,
                subtitle: isCustomerView
                    ? 'Unique customers per venue in each ${_analyticsPeriod.toLowerCase()}'
                    : 'Sales grouped by ${_analyticsPeriod.toLowerCase()}',
                values: values,
                labels: labels,
                detailLabels: detailLabels,
                pointDetails: pointDetails,
                series: venueSeries,
                valueColor: isCustomerView
                    ? const Color(0xFF168B69)
                    : _merchantOrange,
                formatValue: isCustomerView
                    ? (value) => value.round().toString()
                    : _compactCurrency,
                detailFormatter: isCustomerView
                    ? (value) => value.round().toString()
                    : _formatCurrency,
                showDataLabels: false,
                summary: chartSummary,
              ),
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const AppText('Full view', localize: true),
            ),
          ),
          SizedBox(
            height: 270,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                key: ValueKey(
                  isCustomerView
                      ? 'merchant-analytics-customer-chart'
                      : 'merchant-analytics-sales-chart',
                ),
                width: chartWidth,
                child: _AnalyticsLineChart(
                  values: values,
                  labels: labels,
                  detailLabels: detailLabels,
                  pointDetails: pointDetails,
                  series: venueSeries,
                  valueLabel: isCustomerView ? 'Customers' : 'Confirmed sales',
                  valueColor: isCustomerView
                      ? const Color(0xFF168B69)
                      : _merchantOrange,
                  showDataLabels: false,
                  formatValue: isCustomerView
                      ? (value) => value.round().toString()
                      : _compactCurrency,
                  detailFormatter: isCustomerView
                      ? (value) => value.round().toString()
                      : _formatCurrency,
                ),
              ),
            ),
          ),
          const SizedBox(height: _analyticsElementGap),
          _analyticsChartSummary(chartSummary),
        ],
      ),
    );
  }

  List<_AnalyticsChartSeries> get _venueCustomerSeries {
    const colors = [
      Color(0xFF168B69),
      Color(0xFFFF8200),
      Color(0xFF5169C4),
      Color(0xFFB34E91),
      Color(0xFF008FA8),
      Color(0xFFAB6D19),
      Color(0xFF7855A3),
      Color(0xFF4C7A32),
    ];
    final buckets = _analyticsBuckets;
    final names = <String>{
      ..._analyticsBusinesses.map(
        (business) => '${business['name'] ?? 'Venue'}',
      ),
      ..._periodBookings.map((booking) => '${booking['venueName'] ?? 'Venue'}'),
    }.toList()..sort();
    final bucketIndexes = {
      for (var index = 0; index < buckets.length; index++)
        buckets[index].key: index,
    };
    final customersByVenue = <String, List<Set<String>>>{
      for (final name in names)
        name: List.generate(buckets.length, (_) => <String>{}),
    };
    for (final booking in _periodBookings) {
      final date = _bookingDate(booking);
      if (date == null) continue;
      final bucketIndex = bucketIndexes[_analyticsKeyForDate(date)];
      final customer = booking['customerId'] ?? booking['customerName'];
      if (bucketIndex == null || customer == null) continue;
      final venueName = '${booking['venueName'] ?? 'Venue'}';
      customersByVenue
          .putIfAbsent(
            venueName,
            () => List.generate(buckets.length, (_) => <String>{}),
          )[bucketIndex]
          .add('$customer');
    }
    return [
      for (var index = 0; index < names.length; index++)
        _AnalyticsChartSeries(
          name: names[index],
          values: [
            for (final customerSet in customersByVenue[names[index]]!)
              customerSet.length.toDouble(),
          ],
          color: colors[index % colors.length],
        ),
    ];
  }

  Widget get _analyticsVenueComparisonChart {
    const contributionColors = [
      Color(0xFF192B50),
      Color(0xFFFF8200),
      Color(0xFF168B69),
      Color(0xFF5169C4),
      Color(0xFFB34E91),
      Color(0xFF008FA8),
      Color(0xFFAB6D19),
      Color(0xFF7855A3),
    ];
    final venues = _venueAnalytics;
    double valueFor(_VenueAnalytics venue) => switch (_venueComparisonMetric) {
      'Sales' => venue.sales,
      'Players' => venue.participants.toDouble(),
      _ => venue.bookings.toDouble(),
    };
    final ranked = [...venues]
      ..sort((a, b) => valueFor(b).compareTo(valueFor(a)));
    final totalValue = ranked.fold<double>(
      0,
      (total, venue) => total + valueFor(venue),
    );
    final valueColor = switch (_venueComparisonMetric) {
      'Sales' => _merchantOrange,
      'Players' => const Color(0xFF168B69),
      _ => _merchantNavy,
    };
    final metricLabel = _venueComparisonMetric.toLowerCase();
    return _analyticsPanel(
      title: '$_venueComparisonMetric by venue',
      subtitle: 'Compare venues for the selected date range',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            key: const ValueKey('merchant-venue-comparison-metric'),
            expandedInsets: EdgeInsets.zero,
            style: _analyticsFilterStyle,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'Bookings',
                label: AppText('Bookings', localize: true),
              ),
              ButtonSegment(
                value: 'Sales',
                label: AppText('Sales', localize: true),
              ),
              ButtonSegment(
                value: 'Players',
                label: AppText('Players', localize: true),
              ),
            ],
            selected: {_venueComparisonMetric},
            onSelectionChanged: (selection) {
              _setAnalyticsState(
                () => _venueComparisonMetric = selection.first,
              );
            },
          ),
          const SizedBox(height: _analyticsElementGap),
          if (ranked.isEmpty)
            AppText(
              'Venue comparisons will appear when venues are added.',
              style: TextStyle(color: _merchantMuted, fontSize: 13),
              localize: true,
            )
          else ...[
            if (ranked.length > 1) ...[
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      'Share of total $metricLabel',
                      style: TextStyle(
                        color: _merchantInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AppText(
                    _venueComparisonMetric == 'Sales'
                        ? _formatCurrency(totalValue)
                        : '${totalValue.round()} $metricLabel',
                    key: const ValueKey('merchant-venue-contribution-total'),
                    style: TextStyle(
                      color: _merchantMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _analyticsElementGap),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Semantics(
                  label: 'Venue contribution share of total $metricLabel',
                  child: SizedBox(
                    key: const ValueKey('merchant-venue-contribution-chart'),
                    height: 14,
                    child: totalValue <= 0
                        ? ColoredBox(color: _merchantLine)
                        : Row(
                            children: [
                              for (
                                var index = 0;
                                index < ranked.length;
                                index++
                              )
                                if (valueFor(ranked[index]) > 0)
                                  Expanded(
                                    flex: math.max(
                                      1,
                                      (valueFor(ranked[index]) /
                                              totalValue *
                                              1000)
                                          .round(),
                                    ),
                                    child: Tooltip(
                                      message:
                                          '${ranked[index].name}: '
                                          '${(valueFor(ranked[index]) / totalValue * 100).toStringAsFixed(1)}%',
                                      child: ColoredBox(
                                        color:
                                            contributionColors[index %
                                                contributionColors.length],
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: _analyticsElementGap),
              AppText(
                "Each color represents a venue's share of the total.",
                style: TextStyle(color: _merchantMuted, fontSize: 10),
              ),
            ],
            for (final entry in ranked.asMap().entries)
              Padding(
                padding: EdgeInsets.only(
                  top: entry.key == 0 ? 0 : _analyticsElementGap,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            entry.value.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _merchantInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        AppText(
                          '${(totalValue <= 0 ? 0 : valueFor(entry.value) / totalValue * 100).toStringAsFixed(1)}%',
                          key: ValueKey(
                            'merchant-venue-share-${entry.value.name}',
                          ),
                          style: TextStyle(
                            color:
                                contributionColors[entry.key %
                                    contributionColors.length],
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: _analyticsElementGap),
                        AppText(
                          _venueComparisonMetric == 'Sales'
                              ? _formatCurrency(valueFor(entry.value))
                              : valueFor(entry.value).round().toString(),
                          key: ValueKey(
                            'merchant-venue-comparison-value-${entry.value.name}',
                          ),
                          style: TextStyle(
                            color: valueColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _analyticsElementGap),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        key: ValueKey(
                          'merchant-venue-comparison-bar-${entry.value.name}',
                        ),
                        value: totalValue <= 0
                            ? 0
                            : valueFor(entry.value) / totalValue,
                        minHeight: 8,
                        backgroundColor: _merchantLine,
                        color:
                            contributionColors[entry.key %
                                contributionColors.length],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: _analyticsElementGap),
            _analyticsChartSummary(
              '${ranked.length} venues compared · '
              '${_periodBookings.length} bookings in this date range',
            ),
            const SizedBox(height: _analyticsElementGap),
            AppText(
              _venueComparisonMetric == 'Sales'
                  ? 'Sales include confirmed bookings only.'
                  : 'Sorted by $metricLabel from highest to lowest.',
              style: TextStyle(color: _merchantMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAnalyticsChartFullView({
    required String title,
    required String subtitle,
    required List<double> values,
    required List<String> labels,
    required List<String> detailLabels,
    required List<List<_AnalyticsPointMetric>> pointDetails,
    required List<_AnalyticsChartSeries> series,
    required Color valueColor,
    required String Function(double value) formatValue,
    required String Function(double value) detailFormatter,
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
        detailLabels: detailLabels,
        pointDetails: pointDetails,
        series: series,
        valueColor: valueColor,
        formatValue: formatValue,
        detailFormatter: detailFormatter,
        showDataLabels: showDataLabels,
        summary: summary,
      ),
    ),
  );

  Widget _analyticsChartSummary(String summary) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.page,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(Icons.summarize_outlined, color: _merchantInk, size: 19),
        const SizedBox(width: _analyticsElementGap),
        Expanded(
          child: AppText(
            summary,
            style: TextStyle(
              color: _merchantInk,
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
      ..._analyticsBusinesses.map(
        (business) => '${business['name'] ?? 'Venue'}',
      ),
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
    for (final business in _analyticsBusinesses) {
      if ('${business['name'] ?? ''}' == name) {
        return _bookingAmount(
          business['averageRating'] ?? business['average_rating'],
        );
      }
    }
    return 0;
  }

  int _businessReviewCount(String name) {
    for (final business in _analyticsBusinesses) {
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
          ? AppText(
              'Venue performance will appear when bookings come in.',
              style: TextStyle(color: _merchantMuted, fontSize: 13),
              localize: true,
            )
          : Column(
              children: [
                for (final entry in ranked.take(5).toList().asMap().entries)
                  Padding(
                    padding: EdgeInsets.only(
                      top: entry.key == 0 ? 0 : _analyticsElementGap,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: AppColors.softOrange,
                          child: AppText(
                            '${entry.key + 1}',
                            style: TextStyle(
                              color: _merchantInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            localize: true,
                          ),
                        ),
                        const SizedBox(width: _analyticsElementGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                entry.value.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _merchantInk,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: _analyticsElementGap),
                              AppText(
                                '${entry.value.bookings} bookings · '
                                '${entry.value.participants} players · '
                                '${entry.value.reviewCount} reviews',
                                style: TextStyle(
                                  color: _merchantMuted,
                                  fontSize: 11,
                                ),
                                localize: true,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AppText(
                              _formatCurrency(entry.value.sales),
                              style: TextStyle(
                                color: _merchantInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: _analyticsElementGap),
                            AppText(
                              entry.value.rating > 0
                                  ? '★ ${entry.value.rating.toStringAsFixed(1)}'
                                  : 'No rating',
                              style: TextStyle(
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
    final confirmedCount = _analyticsBookings.where(_isConfirmedBooking).length;
    final finishedCount = _analyticsBookings.where(_isFinishedBooking).length;
    return _analyticsPanel(
      title: 'Bookings overview',
      subtitle: 'Current status across all venues',
      child: Row(
        children: [
          Expanded(
            child: _statusMetric(
              'Pending',
              _analyticsBookings.where(_isPendingBooking).length,
            ),
          ),
          Expanded(
            child: _statusMetric('Approved', confirmedCount - finishedCount),
          ),
          Expanded(child: _statusMetric('Finished', finishedCount)),
          Expanded(
            child: _statusMetric(
              'Cancelled',
              _analyticsBookings
                  .where(
                    (booking) =>
                        BookingStatusParser.isCancelled(booking['status']),
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
      AppText(
        '$value',
        style: TextStyle(
          color: _merchantInk,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
        localize: true,
      ),
      const SizedBox(height: _analyticsElementGap),
      AppText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _merchantMuted, fontSize: 10),
      ),
    ],
  );

  Widget _analyticsPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            key: ValueKey(
              'merchant-analytics-panel-${title.toLowerCase().replaceAll(' ', '-')}',
            ),
            style: TextStyle(
              color: _merchantInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: _analyticsElementGap),
          AppText(
            subtitle,
            style: TextStyle(color: _merchantMuted, fontSize: 11),
          ),
          const SizedBox(height: _analyticsElementGap),
          child,
        ],
      ),
    ),
  );

  String _formatCurrency(double value) =>
      '\u{20B1} ${value.toStringAsFixed(2)}';

  String _compactCurrency(double value) {
    if (value >= 1000000) return '₱${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '₱${(value / 1000).toStringAsFixed(1)}k';
    return '₱${value.round()}';
  }
}
