import 'package:flutter/material.dart';

import 'app_session.dart';
import 'auth_api.dart';

class ReviewsSheet extends StatefulWidget {
  const ReviewsSheet({
    super.key,
    required this.api,
    required this.businessId,
    required this.businessName,
    this.onSubmitted,
  });

  final AuthApi api;
  final int businessId;
  final String businessName;
  final VoidCallback? onSubmitted;

  @override
  State<ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<ReviewsSheet> {
  List<Map<String, dynamic>> _reviews = const [];
  Object? _error;
  var _loading = true;
  var _rating = 5;
  var _submitting = false;
  var _canSubmitReview = false;
  var _eligibilityMessage =
      'Complete a booking at this venue before reviewing it.';
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    try {
      final token = (await AppSession.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Please sign in to view reviews.', 401);
      }
      final reviews = await widget.api.newsReviews(
        token: token,
        businessId: widget.businessId,
      );
      final bookings = await widget.api.customerBookingModels(token);
      final venueBookings = bookings.where(
        (booking) => booking.venue.id == widget.businessId,
      );
      final finishedBooking = venueBookings.where(
        (booking) => booking.status == 'finished',
      );
      final canSubmit = finishedBooking.any(
        (booking) => booking.reviewId == null,
      );
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _canSubmitReview = canSubmit;
          _eligibilityMessage = canSubmit
              ? ''
              : finishedBooking.isEmpty
              ? 'Only customers with a completed booking can submit a review.'
              : 'You already reviewed your completed booking.';
          _loading = false;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    final token = (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) {
      _showError('Please sign in to submit a review.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.api.createNewsReview(
        token: token,
        businessId: widget.businessId,
        rating: _rating,
        comment: _comment.text.trim(),
      );
      _comment.clear();
      await _loadReviews();
      widget.onSubmitted?.call();
      if (mounted) setState(() => _submitting = false);
    } on Exception catch (error) {
      if (mounted) setState(() => _submitting = false);
      _showError('$error');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratedUsers = _reviews
        .map((review) => review['customerId'] ?? review['customer_id'])
        .where((id) => id != null)
        .toSet()
        .length;
    final average = _reviews.isEmpty
        ? 0.0
        : _reviews
                  .map((review) => double.tryParse('${review['rating']}') ?? 0)
                  .fold<double>(0, (total, value) => total + value) /
              _reviews.length;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DCE4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.businessName} reviews',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const LinearProgressIndicator(minHeight: 3)
              else if (_error != null)
                _errorState()
              else ...[
                Row(
                  children: [
                    Text(
                      _reviews.isEmpty
                          ? 'New venue'
                          : average.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Color(0xFF101B33),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded, color: Colors.amber),
                    const SizedBox(width: 12),
                    Text(
                      '${_reviews.length} reviews · $ratedUsers rated',
                      style: const TextStyle(
                        color: Color(0xFF68748A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(child: _reviewList()),
                const Divider(height: 24),
                _reviewForm(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState() => Expanded(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load reviews.'),
          Text('$_error', textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadReviews();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _reviewList() {
    if (_reviews.isEmpty) {
      return const Center(
        child: Text(
          'No reviews yet. Be the first to rate this venue after a completed booking.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: _reviews.length,
      separatorBuilder: (_, _) => const Divider(height: 20),
      itemBuilder: (_, index) {
        final review = _reviews[index];
        final name = [
          '${review['firstName'] ?? ''}'.trim(),
          '${review['lastName'] ?? ''}'.trim(),
        ].where((value) => value.isNotEmpty).join(' ');
        final rating = int.tryParse('${review['rating']}') ?? 0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFFFE8D2),
            child: Text(name.isEmpty ? 'U' : name[0].toUpperCase()),
          ),
          title: Text(name.isEmpty ? 'Customer' : name),
          subtitle: Text('${review['comment'] ?? ''}'),
          trailing: Text('$rating/5'),
        );
      },
    );
  }

  Widget _reviewForm() {
    if (!_canSubmitReview) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E7EF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFF68748A)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _eligibilityMessage,
                style: const TextStyle(color: Color(0xFF68748A), height: 1.35),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leave a review after your completed booking',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber,
                ),
              ),
          ],
        ),
        TextField(
          controller: _comment,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Comment'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submitReview,
            child: Text(_submitting ? 'Submitting...' : 'Submit review'),
          ),
        ),
      ],
    );
  }
}
