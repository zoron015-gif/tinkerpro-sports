part of 'merchant_dashboard.dart';

class _AnalyticsLineChart extends StatelessWidget {
  const _AnalyticsLineChart({
    required this.values,
    required this.labels,
    required this.valueColor,
    required this.formatValue,
    this.showDataLabels = false,
  });

  final List<double> values;
  final List<String> labels;
  final Color valueColor;
  final String Function(double value) formatValue;
  final bool showDataLabels;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _AnalyticsLineChartPainter(
      values: values,
      labels: labels,
      valueColor: valueColor,
      mutedColor: _merchantMuted,
      lineColor: _merchantLine,
      formatValue: formatValue,
      showDataLabels: showDataLabels,
    ),
    child: const SizedBox.expand(),
  );
}

class _AnalyticsFullChartPage extends StatelessWidget {
  const _AnalyticsFullChartPage({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labels,
    required this.valueColor,
    required this.formatValue,
    required this.showDataLabels,
    required this.summary,
  });

  final String title;
  final String subtitle;
  final List<double> values;
  final List<String> labels;
  final Color valueColor;
  final String Function(double value) formatValue;
  final bool showDataLabels;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final chartWidth = math
        .max(MediaQuery.sizeOf(context).width - 32, values.length * 56.0)
        .toDouble();
    return Scaffold(
      backgroundColor: _merchantPage,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _merchantPage,
        foregroundColor: _merchantInk,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const ValueKey('merchant-analytics-chart-close'),
            tooltip: 'Close full chart',
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
              Text(
                subtitle,
                style: const TextStyle(color: _merchantMuted, fontSize: 13),
              ),
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
                      valueColor: valueColor,
                      formatValue: formatValue,
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

class _FullChartSummary extends StatelessWidget {
  const _FullChartSummary({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _merchantLine),
    ),
    child: Text(
      summary,
      style: const TextStyle(
        color: _merchantNavy,
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
    color: selected ? const Color(0xFFFFF1E4) : Colors.white,
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
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _merchantNavy : _merchantMuted,
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
    required this.valueColor,
    required this.mutedColor,
    required this.lineColor,
    required this.formatValue,
    required this.showDataLabels,
  });

  final List<double> values;
  final List<String> labels;
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
    final maxValue = values.fold<double>(
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
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = slotWidth * (index + .5);
      final y = top + chartHeight - chartHeight * values[index] / scaleMax;
      points.add(Offset(x, y));
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
