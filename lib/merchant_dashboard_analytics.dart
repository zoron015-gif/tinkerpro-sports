part of 'merchant_dashboard.dart';

class _AnalyticsChartSeries {
  const _AnalyticsChartSeries({
    required this.name,
    required this.values,
    required this.color,
  });

  final String name;
  final List<double> values;
  final Color color;
}

class _AnalyticsLineChart extends StatefulWidget {
  const _AnalyticsLineChart({
    required this.values,
    required this.labels,
    required this.detailLabels,
    required this.valueColor,
    required this.formatValue,
    required this.detailFormatter,
    required this.valueLabel,
    this.series = const [],
    this.showDataLabels = false,
  });

  final List<double> values;
  final List<String> labels;
  final List<String> detailLabels;
  final Color valueColor;
  final String Function(double value) formatValue;
  final String Function(double value) detailFormatter;
  final String valueLabel;
  final List<_AnalyticsChartSeries> series;
  final bool showDataLabels;

  @override
  State<_AnalyticsLineChart> createState() => _AnalyticsLineChartState();
}

class _AnalyticsLineChartState extends State<_AnalyticsLineChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _AnalyticsLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedIndex = null;
  }

  void _selectPoint(Offset position, Size size) {
    if (widget.labels.isEmpty || size.width <= 0) return;
    final index = (position.dx / size.width * widget.labels.length)
        .floor()
        .clamp(0, widget.labels.length - 1);
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        Expanded(
          child: Listener(
            key: ValueKey('merchant-chart-plot-${widget.valueLabel}'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                _selectPoint(event.localPosition, constraints.biggest),
            onPointerMove: (event) =>
                _selectPoint(event.localPosition, constraints.biggest),
            child: CustomPaint(
              painter: _AnalyticsLineChartPainter(
                values: widget.values,
                labels: widget.labels,
                series: widget.series,
                selectedIndex: _selectedIndex,
                valueColor: widget.valueColor,
                mutedColor: _merchantMuted,
                lineColor: _merchantLine,
                formatValue: widget.formatValue,
                showDataLabels: widget.showDataLabels,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        if (_selectedIndex case final selectedIndex?)
          _selectedPointDetails(selectedIndex)
        else
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: AppText(
              'Tap or drag across the chart to inspect exact values.',
              style: TextStyle(color: _merchantMuted, fontSize: 11),
             localize: true,),
          ),
      ],
    ),
  );

  Widget _selectedPointDetails(int index) {
    final rows = widget.series.isEmpty
        ? [
            (
              name: widget.valueLabel,
              value: widget.values[index],
              color: widget.valueColor,
            ),
          ]
        : [
            for (final item in widget.series)
              (name: item.name, value: item.values[index], color: item.color),
          ];
    return Container(
      key: const ValueKey('merchant-analytics-selected-point'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            widget.detailLabels[index],
            style: TextStyle(
              color: _merchantInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 78),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: row.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppText(
                              row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _merchantMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppText(
                            widget.series.isEmpty
                                ? widget.detailFormatter(row.value)
                                : '${widget.detailFormatter(row.value)} customers',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: row.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsFullChartPage extends StatelessWidget {
  const _AnalyticsFullChartPage({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labels,
    required this.detailLabels,
    required this.valueColor,
    required this.formatValue,
    required this.series,
    required this.detailFormatter,
    required this.showDataLabels,
    required this.summary,
  });

  final String title;
  final String subtitle;
  final List<double> values;
  final List<String> labels;
  final List<String> detailLabels;
  final Color valueColor;
  final String Function(double value) formatValue;
  final List<_AnalyticsChartSeries> series;
  final String Function(double value) detailFormatter;
  final bool showDataLabels;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final chartWidth = math
        .max(MediaQuery.sizeOf(context).width - 32, labels.length * 56.0)
        .toDouble();
    return Scaffold(
      backgroundColor: _merchantPage,
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        leadingWidth: 56,
        titleTextStyle: AppTypography.pageTitle,
        title: AppText(title),
        backgroundColor: _merchantPage,
        foregroundColor: _merchantInk,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const ValueKey('merchant-analytics-chart-close'),
            tooltip: appLanguageText('Close full chart', 'Close full chart'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                subtitle,
                style: TextStyle(color: _merchantMuted, fontSize: 13),
              ),
              if (series.isNotEmpty) ...[
                const SizedBox(height: 12),
                _AnalyticsChartLegend(series: series),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    key: const ValueKey('merchant-analytics-chart-full'),
                    width: chartWidth,
                    child: _AnalyticsLineChart(
                      values: values,
                      labels: labels,
                      detailLabels: detailLabels,
                      series: series,
                      valueColor: valueColor,
                      formatValue: formatValue,
                      detailFormatter: detailFormatter,
                      valueLabel: title.startsWith('Sales')
                          ? 'Confirmed sales'
                          : 'Customers',
                      showDataLabels: showDataLabels,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _FullChartSummary(summary: summary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsChartLegend extends StatelessWidget {
  const _AnalyticsChartLegend({required this.series});

  final List<_AnalyticsChartSeries> series;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 7,
    children: [
      for (final item in series)
        Row(
          key: ValueKey('merchant-analytics-legend-${item.name}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: AppText(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _merchantMuted, fontSize: 11),
              ),
            ),
          ],
        ),
    ],
  );
}

class _FullChartSummary extends StatelessWidget {
  const _FullChartSummary({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _merchantLine),
    ),
    child: AppText(
      summary,
      style: TextStyle(
        color: _merchantInk,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _AnalyticsViewTile extends StatelessWidget {
  const _AnalyticsViewTile({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.softOrangeAlt : Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _merchantOrange : _merchantLine,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? _merchantOrange : _merchantMuted,
              size: 20,
            ),
            const SizedBox(height: 5),
            AppText(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _merchantInk : _merchantMuted,
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AnalyticsLineChartPainter extends CustomPainter {
  const _AnalyticsLineChartPainter({
    required this.values,
    required this.labels,
    required this.series,
    required this.selectedIndex,
    required this.valueColor,
    required this.mutedColor,
    required this.lineColor,
    required this.formatValue,
    required this.showDataLabels,
  });

  final List<double> values;
  final List<String> labels;
  final List<_AnalyticsChartSeries> series;
  final int? selectedIndex;
  final Color valueColor;
  final Color mutedColor;
  final Color lineColor;
  final String Function(double value) formatValue;
  final bool showDataLabels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || labels.isEmpty) return;
    const top = 16.0;
    const bottom = 26.0;
    final chartHeight = math.max(1.0, size.height - top - bottom).toDouble();
    final allValues = series.isEmpty
        ? values
        : series.expand((item) => item.values).toList();
    final maxValue = allValues.fold<double>(
      0,
      (current, value) => math.max(current, value).toDouble(),
    );
    final scaleMax = maxValue == 0 ? 1.0 : maxValue;
    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = top + chartHeight * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final slotWidth = size.width / values.length;
    for (var index = 0; index < values.length; index++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: TextStyle(
            color: mutedColor,
            fontSize: labels.length > 8 ? 8 : 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: slotWidth);
      textPainter.paint(
        canvas,
        Offset(
          slotWidth * index + (slotWidth - textPainter.width) / 2,
          top + chartHeight + 6,
        ),
      );
    }
    if (series.isNotEmpty) {
      for (final item in series) {
        final points = <Offset>[];
        for (var index = 0; index < item.values.length; index++) {
          final x = slotWidth * (index + .5);
          final y =
              top + chartHeight - chartHeight * item.values[index] / scaleMax;
          points.add(Offset(x, y));
        }
        if (points.length > 1) {
          final path = Path()..moveTo(points.first.dx, points.first.dy);
          for (final point in points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = item.color
              ..strokeWidth = 2.5
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          );
        }
        for (final point in points) {
          canvas.drawCircle(point, 3.5, Paint()..color = item.color);
          canvas.drawCircle(point, 1.6, Paint()..color = Colors.white);
        }
        if (selectedIndex != null && selectedIndex! < points.length) {
          canvas.drawCircle(
            points[selectedIndex!],
            6,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          canvas.drawCircle(
            points[selectedIndex!],
            4,
            Paint()..color = item.color,
          );
        }
      }
    } else {
      final points = <Offset>[];
      for (var index = 0; index < values.length; index++) {
        final x = slotWidth * (index + .5);
        final y = top + chartHeight - chartHeight * values[index] / scaleMax;
        points.add(Offset(x, y));
      }
      if (points.length > 1) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = valueColor
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      for (final point in points) {
        canvas.drawCircle(point, 3.5, Paint()..color = valueColor);
        canvas.drawCircle(point, 1.6, Paint()..color = Colors.white);
      }
      if (selectedIndex != null && selectedIndex! < points.length) {
        canvas.drawCircle(
          points[selectedIndex!],
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawCircle(
          points[selectedIndex!],
          4,
          Paint()..color = valueColor,
        );
      }
      if (showDataLabels) {
        for (var index = 0; index < points.length; index++) {
          final labelPainter = TextPainter(
            text: TextSpan(
              text: formatValue(values[index]),
              style: TextStyle(
                color: valueColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: slotWidth);
          labelPainter.paint(
            canvas,
            Offset(
              (points[index].dx - labelPainter.width / 2).clamp(
                0,
                size.width - labelPainter.width,
              ),
              math.max(top, points[index].dy - labelPainter.height - 5),
            ),
          );
        }
      }
    }
    if (selectedIndex != null && selectedIndex! < values.length) {
      final selectedX = slotWidth * (selectedIndex! + .5);
      canvas.drawLine(
        Offset(selectedX, top),
        Offset(selectedX, top + chartHeight),
        Paint()
          ..color = mutedColor.withValues(alpha: .45)
          ..strokeWidth = 1,
      );
    }
    final maxPainter = TextPainter(
      text: TextSpan(
        text: formatValue(maxValue),
        style: TextStyle(color: mutedColor, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    if (!showDataLabels) maxPainter.paint(canvas, Offset(0, 0));
  }

  @override
  bool shouldRepaint(covariant _AnalyticsLineChartPainter oldDelegate) => true;
}
