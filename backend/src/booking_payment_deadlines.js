const paymentExpirationCandidatesSql = `
  SELECT b.id, b.customer_id AS customerId,
         v.merchant_id AS merchantId, b.venue_id AS venueId,
         v.name AS venueName, b.total_amount AS totalAmount,
         b.downpayment_amount AS downpaymentAmount,
         b.payment_method AS paymentMethod,
         b.payment_due_at AS paymentDueAt
  FROM bookings b
  JOIN merchant_businesses v ON v.id = b.venue_id
  WHERE b.status = 'approved'
    AND b.payment_method IN ('online', 'cash_on_arrival')
    AND b.payment_status = 'unpaid'
    AND b.payment_due_at <= CURRENT_TIMESTAMP
    AND b.payment_expired_at IS NULL
  ORDER BY b.id
`;

function createBookingPaymentDeadlineProcessor({ pool, recordUserActivity }) {
  let running = false;

  return async function processPaymentDeadlines() {
    if (running) return;
    running = true;
    try {
      const [candidates] = await pool.execute(paymentExpirationCandidatesSql);
      for (const booking of candidates) {
        const connection = await pool.getConnection();
        try {
          await connection.beginTransaction();
          const [result] = await connection.execute(
            `UPDATE bookings
             SET status = 'cancelled',
                 payment_expired_at = CURRENT_TIMESTAMP
             WHERE id = ? AND status = 'approved'
               AND payment_method IN ('online', 'cash_on_arrival')
               AND payment_status = 'unpaid'
               AND payment_due_at <= CURRENT_TIMESTAMP
               AND payment_expired_at IS NULL`,
            [booking.id],
          );
          if (!result.affectedRows) {
            await connection.rollback();
            continue;
          }

          const transactionId = `TP-TXN-${String(booking.id).padStart(8, '0')}`;
          const bookingReference = `BK-${booking.id}`;
          const payableAmount = booking.paymentMethod === 'online'
            ? Number(booking.totalAmount)
            : Number(booking.downpaymentAmount);
          const [conversations] = await connection.execute(
            'SELECT id FROM conversations WHERE type = ? AND title = ? LIMIT 1',
            ['direct', `Booking ${booking.id}`],
          );
          if (!conversations[0]) {
            throw new Error(
              `Approved booking ${booking.id} has no booking conversation.`,
            );
          }
          const message =
            `The booking at ${booking.venueName} expired because the required amount was not paid within 15 minutes after approval. ` +
            `The reservation is no longer active. Transaction ID: ${transactionId}. ` +
            `Booking reference: ${bookingReference}.`;
          await connection.execute(
            `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
             VALUES (?, ?, ?, ?)`,
            [
              conversations[0].id,
              booking.merchantId,
              message,
              JSON.stringify({
                type: 'booking_ticket',
                bookingId: booking.id,
                transactionId,
                bookingReference,
                venueName: booking.venueName,
                amount: Number(booking.totalAmount),
                payableAmount,
                paymentDueAt: booking.paymentDueAt,
                paymentExpiredAt: new Date().toISOString(),
                status: 'payment_expired',
                approvalStatus: 'payment_expired',
                totalAmount: Number(booking.totalAmount),
                paymentMethod: booking.paymentMethod,
                paymentStatus: 'unpaid',
              }),
            ],
          );

          const details = {
            venueId: booking.venueId,
            venueName: booking.venueName,
            details: {
              bookingId: booking.id,
              transactionId,
              bookingReference,
              amount: Number(booking.totalAmount),
            },
          };
          for (const userId of [booking.customerId, booking.merchantId]) {
            await recordUserActivity(
              connection,
              userId,
              'booking_payment_expired',
              'Booking expired — payment window ended',
              message,
              details,
              { systemGenerated: true },
            );
          }
          await connection.commit();
        } catch (error) {
          await connection.rollback();
          throw error;
        } finally {
          connection.release();
        }
      }
    } finally {
      running = false;
    }
  };
}

module.exports = {
  createBookingPaymentDeadlineProcessor,
  paymentExpirationCandidatesSql,
};
