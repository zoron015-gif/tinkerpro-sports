const reminderCandidatesSql = `
  SELECT b.id, b.customer_id AS customerId,
         v.merchant_id AS merchantId, b.venue_id AS venueId,
         v.name AS venueName, COALESCE(b.sport_type, v.category) AS sportType
  FROM bookings b
  JOIN merchant_businesses v ON v.id = b.venue_id
  WHERE b.status = 'pending' AND b.approval_reminded_at IS NULL
    AND b.created_at <= CURRENT_TIMESTAMP - INTERVAL 10 MINUTE
  ORDER BY b.id
`;

const expirationCandidatesSql = `
  SELECT b.id, b.customer_id AS customerId,
         v.merchant_id AS merchantId, b.venue_id AS venueId,
         v.name AS venueName, COALESCE(b.sport_type, v.category) AS sportType
  FROM bookings b
  JOIN merchant_businesses v ON v.id = b.venue_id
  WHERE b.status = 'pending'
    AND b.created_at <= CURRENT_TIMESTAMP - INTERVAL 15 MINUTE
  ORDER BY b.id
`;

function createBookingApprovalDeadlineProcessor({
  pool,
  recordUserActivity,
}) {
  let running = false;

  async function processDeadlines() {
    if (running) return;
    running = true;

    try {
      const [reminderCandidates] = await pool.execute(reminderCandidatesSql);
      for (const booking of reminderCandidates) {
        const connection = await pool.getConnection();
        try {
          await connection.beginTransaction();
          const [result] = await connection.execute(
            `UPDATE bookings
             SET approval_reminded_at = CURRENT_TIMESTAMP
             WHERE id = ? AND status = 'pending'
               AND approval_reminded_at IS NULL
               AND created_at <= CURRENT_TIMESTAMP - INTERVAL 10 MINUTE`,
            [booking.id],
          );
          if (!result.affectedRows) {
            await connection.rollback();
            continue;
          }

          await recordUserActivity(
            connection,
            booking.merchantId,
            'booking_approval_reminder',
            'Booking awaiting your approval',
            `Booking #${booking.id} for ${booking.venueName} has been waiting for your response for 10 minutes.`,
            {
              venueId: booking.venueId,
              venueName: booking.venueName,
              sportType: booking.sportType,
              details: { bookingId: booking.id },
            },
            { systemGenerated: true },
          );
          await connection.commit();
        } catch (error) {
          await connection.rollback();
          throw error;
        } finally {
          connection.release();
        }
      }

      const [expirationCandidates] = await pool.execute(
        expirationCandidatesSql,
      );
      for (const booking of expirationCandidates) {
        const connection = await pool.getConnection();
        try {
          await connection.beginTransaction();
          const [result] = await connection.execute(
            `UPDATE bookings
            SET status = 'cancelled'
            WHERE id = ? AND status = 'pending'
              AND created_at <= CURRENT_TIMESTAMP - INTERVAL 15 MINUTE`,
            [booking.id],
          );
          if (!result.affectedRows) {
            await connection.rollback();
            continue;
          }

          const details = {
            venueId: booking.venueId,
            venueName: booking.venueName,
            sportType: booking.sportType,
            details: { bookingId: booking.id },
          };
          const description =
            `Booking request #${booking.id} for ${booking.venueName} expired after 15 minutes without merchant approval.`;
          await connection.execute(
            `UPDATE messages m
             JOIN conversations c ON c.id = m.conversation_id
             SET m.attachment_json = JSON_SET(
               m.attachment_json, '$.status', 'expired',
               '$.approvalStatus', 'expired'
             )
             WHERE c.title = ? AND c.type = 'direct'
               AND CASE WHEN JSON_VALID(m.attachment_json)
                        THEN JSON_UNQUOTE(JSON_EXTRACT(
                          m.attachment_json, '$.type'
                        )) END = 'booking'
               AND CASE WHEN JSON_VALID(m.attachment_json)
                        THEN JSON_UNQUOTE(JSON_EXTRACT(
                          m.attachment_json, '$.bookingId'
                        )) END = ?`,
            [`Booking ${booking.id}`, String(booking.id)],
          );
          await recordUserActivity(
            connection,
            booking.customerId,
            'booking_auto_cancelled',
            'Booking request expired',
            description,
            details,
            { systemGenerated: true },
          );
          await recordUserActivity(
            connection,
            booking.merchantId,
            'booking_auto_cancelled',
            'Booking request expired',
            description,
            details,
            { systemGenerated: true },
          );
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
  }

  return processDeadlines;
}

module.exports = {
  createBookingApprovalDeadlineProcessor,
  expirationCandidatesSql,
  reminderCandidatesSql,
};
