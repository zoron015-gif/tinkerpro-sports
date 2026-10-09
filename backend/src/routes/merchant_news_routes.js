function newsPostResponse(row) {
  const parseArray = (value) => {
    if (Array.isArray(value)) return value;
    if (typeof value !== 'string' || value.trim() === '') return [];
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  };
  return {
    id: Number(row.id),
    businessId: Number(row.business_id),
    status: row.status,
    title: row.title,
    body: row.body,
    imageUrl: row.image_url || row.business_image_url || null,
    businessName: row.business_name || row.venue_name,
    businessType: row.business_type || null,
    category: row.business_category || null,
    address: row.business_address || row.venue_address,
    facilityType: row.facility_type || null,
    hours: row.opening_hours || null,
    availability: row.availability || null,
    pricePerHour: row.price_per_hour ?? null,
    slotCount: Number(row.slot_count || 1),
    sportsSlots: parseArray(row.sports_slots_json),
    eventFee: row.event_fee ?? null,
    eventTypes: parseArray(row.event_types_json),
    ratePeriods: parseArray(row.rate_periods),
    tags: parseArray(row.amenities_json),
    details: row.business_details || null,
    imageUrls: parseArray(row.image_urls),
    businessImageUrl: row.business_image_url || null,
    visitUrl: row.visit_url || null,
    latitude:
      row.latitude === null || row.latitude === undefined
        ? null
        : Number(row.latitude),
    longitude:
      row.longitude === null || row.longitude === undefined
        ? null
        : Number(row.longitude),
    merchantName: [row.merchant_first_name, row.merchant_last_name]
      .filter(Boolean)
      .join(' ') || 'Venue owner',
    merchantEmail: row.merchant_email || null,
    merchantPhone: row.merchant_phone || null,
    merchantAvatarUrl: row.merchant_avatar_url || null,
    enabled: !(
      row.enabled === false ||
      row.enabled === 0 ||
      row.enabled === '0' ||
      row.enabled === 'false' ||
      row.enabled === 'FALSE'
    ),
    businessEnabled: !(
      row.enabled === false ||
      row.enabled === 0 ||
      row.enabled === '0' ||
      row.enabled === 'false' ||
      row.enabled === 'FALSE'
    ),
    averageRating: Number(row.average_rating || 0),
    reviewCount: Number(row.review_count || 0),
    ratingUserCount: Number(row.rating_user_count || 0),
    heartCount: Number(row.heart_count || 0),
    heartedByMe:
      row.hearted_by_me === true ||
      row.hearted_by_me === 1 ||
      row.hearted_by_me === '1',
  };
}

function registerMerchantNewsRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  normalizeText,
  invalidateCustomerBusinesses,
  recordUserActivity,
}) {
  // Merchant news posts and the customer news feed.
  async function merchantNewsPosts(req, res, next) {
    try {
      const [rows] = await pool.execute(
        `SELECT n.*, b.name AS business_name, b.business_type,
                b.category AS business_category, b.address AS business_address,
                b.latitude, b.longitude,
                b.facility_type, b.opening_hours, b.availability,
                b.price_per_hour, b.event_fee, b.rate_periods,
                b.slot_count, b.sports_slots_json,
                b.amenities_json, b.details AS business_details,
                b.image_url AS business_image_url, b.image_urls, b.enabled,
                b.visit_url
         FROM merchant_news n
         INNER JOIN merchant_businesses b ON b.id = n.business_id
         WHERE b.merchant_id = ? ORDER BY n.created_at DESC`,
        [req.auth.sub],
      );
      return res.json({ posts: rows.map(newsPostResponse) });
    } catch (error) { return next(error); }
  }

  async function createMerchantNewsPost(req, res, next) {
    const businessId = positiveIntegerId(req.body.businessId ?? req.body.venueId);
    const title = normalizeText(req.body.title, 255);
    const body = normalizeText(req.body.body, 5000);
    const status = req.body.status || 'published';
    if (businessId === null || !title || !body ||
        typeof req.body.title !== 'string' || req.body.title.length > 255 ||
        typeof req.body.body !== 'string' || req.body.body.length > 5000 ||
        (req.body.status !== undefined && typeof req.body.status !== 'string') ||
        !['draft', 'published', 'archived'].includes(status) ||
        (req.body.imageUrl != null &&
          (typeof req.body.imageUrl !== 'string' ||
            req.body.imageUrl.length > 10 * 1024 * 1024))) {
      return res.status(400).json({ error: 'businessId, title, body, and a valid status are required.' });
    }
    try {
      const [businesses] = await pool.execute(
        'SELECT id, image_url, image_urls FROM merchant_businesses WHERE id = ? AND merchant_id = ? LIMIT 1',
        [businessId, req.auth.sub],
      );
      if (!businesses[0]) return res.status(404).json({ error: 'Business not found.' });
      const imageUrl = businesses[0].image_url || null;
      if (!imageUrl) {
        return res.status(400).json({
          error: 'Add a venue image to the Booking Card before creating a News Card.',
        });
      }
      const [result] = await pool.execute(
        `INSERT INTO merchant_news (business_id, title, body, image_url, status)
         VALUES (?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           id = LAST_INSERT_ID(id),
           title = VALUES(title),
           body = VALUES(body),
           image_url = VALUES(image_url),
           status = VALUES(status)`,
        [businessId, title, body, imageUrl, status],
      );
      invalidateCustomerBusinesses();
      if (result.affectedRows > 0) {
        const created = result.affectedRows === 1;
        await recordUserActivity(
          pool,
          req.auth.sub,
          created ? 'news_post_created' : 'news_post_updated',
          created ? 'News post created' : 'News post updated',
          `News post #${result.insertId} was ${created ? 'created' : 'updated'} for business #${businessId}.`,
          {
            venueId: businessId,
            details: {
              businessId,
              newsPostId: result.insertId,
              status,
            },
          },
        );
        return res.status(created ? 201 : 200).json({
          id: result.insertId,
          message: created ? 'News post created.' : 'News post updated.',
        });
      }
      return res.json({
        id: result.insertId,
        message: 'News post already up to date.',
      });
    } catch (error) { return next(error); }
  }

  async function updateMerchantNewsPost(req, res, next) {
    const id = positiveIntegerId(req.params.id);
    const title = normalizeText(req.body.title, 255);
    const body = normalizeText(req.body.body, 5000);
    const status = req.body.status || 'draft';
    if (id === null || !title || !body ||
        typeof req.body.title !== 'string' || req.body.title.length > 255 ||
        typeof req.body.body !== 'string' || req.body.body.length > 5000 ||
        (req.body.status !== undefined && typeof req.body.status !== 'string') ||
        !['draft', 'published', 'archived'].includes(status) ||
        (req.body.imageUrl != null &&
          (typeof req.body.imageUrl !== 'string' ||
            req.body.imageUrl.length > 10 * 1024 * 1024))) {
      return res.status(400).json({ error: 'A valid title, body, and status are required.' });
    }
    try {
      const [result] = await pool.execute(
        `UPDATE merchant_news n INNER JOIN merchant_businesses b ON b.id = n.business_id
         SET n.title = ?, n.body = ?, n.status = ?, n.image_url = b.image_url
         WHERE n.id = ? AND b.merchant_id = ?`,
        [title, body, status, id, req.auth.sub],
      );
      if (!result.affectedRows) return res.status(404).json({ error: 'News post not found.' });
      invalidateCustomerBusinesses();
      await recordUserActivity(
        pool,
        req.auth.sub,
        'news_post_updated',
        'News post updated',
        `News post #${id} was updated.`,
        { details: { newsPostId: id, status } },
      );
      return res.json({ message: 'News post updated.' });
    } catch (error) { return next(error); }
  }

  async function deleteMerchantNewsPost(req, res, next) {
    const id = positiveIntegerId(req.params.id);
    if (id === null) return res.status(400).json({ error: 'Invalid news post id.' });
    try {
      const [result] = await pool.execute(
        `DELETE n FROM merchant_news n INNER JOIN merchant_businesses b ON b.id = n.business_id
         WHERE n.id = ? AND b.merchant_id = ?`,
        [id, req.auth.sub],
      );
      if (!result.affectedRows) return res.status(404).json({ error: 'News post not found.' });
      invalidateCustomerBusinesses();
      await recordUserActivity(
        pool,
        req.auth.sub,
        'news_post_deleted',
        'News post deleted',
        `News post #${id} was deleted.`,
        { details: { newsPostId: id } },
      );
      return res.json({ message: 'News post deleted.' });
    } catch (error) { return next(error); }
  }

  app.get('/api/merchant/news', requireAuth, requireRole('merchant'), merchantNewsPosts);
  app.post('/api/merchant/news', requireAuth, requireRole('merchant'), createMerchantNewsPost);
  app.put('/api/merchant/news/:id', requireAuth, requireRole('merchant'), updateMerchantNewsPost);
  app.delete('/api/merchant/news/:id', requireAuth, requireRole('merchant'), deleteMerchantNewsPost);
  app.get('/api/merchant/news-posts', requireAuth, requireRole('merchant'), merchantNewsPosts);
  app.post('/api/merchant/news-posts', requireAuth, requireRole('merchant'), createMerchantNewsPost);
  app.put('/api/merchant/news-posts/:id', requireAuth, requireRole('merchant'), updateMerchantNewsPost);
  app.delete('/api/merchant/news-posts/:id', requireAuth, requireRole('merchant'), deleteMerchantNewsPost);
}

module.exports = { newsPostResponse, registerMerchantNewsRoutes };
