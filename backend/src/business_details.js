const { eventDetailsFromBody, isNumericInput } = require('./normalizers');

async function saveEventDetails(executor, businessId, body) {
  if (body.businessType !== 'Event') {
    await executor.execute(
      'DELETE FROM event_business_details WHERE business_id = ?',
      [businessId],
    );
    return;
  }
  const details = eventDetailsFromBody(body);
  await executor.execute(
    `INSERT INTO event_business_details
       (business_id, event_types_json, attendance_min, attendance_max,
        accessibility_needs, parking_needs, security_needs)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       event_types_json = VALUES(event_types_json),
       attendance_min = VALUES(attendance_min),
       attendance_max = VALUES(attendance_max),
       accessibility_needs = VALUES(accessibility_needs),
       parking_needs = VALUES(parking_needs),
       security_needs = VALUES(security_needs)`,
    [
      businessId,
      JSON.stringify(details.eventTypes),
      details.attendanceMin,
      details.attendanceMax,
      JSON.stringify(details.accessibilityNeeds),
      JSON.stringify(details.parkingNeeds),
      JSON.stringify(details.securityNeeds),
    ],
  );
}

function fitnessDetailsFromBody(body) {
  if (body.businessType !== 'Fitness & Wellness') {
    return { valid: true, categories: [], coaches: [] };
  }
  const categories = Array.isArray(body.fitnessCategories)
    ? body.fitnessCategories
    : [];
  const coaches = Array.isArray(body.fitnessCoaches)
    ? body.fitnessCoaches
    : [];
  const categoryNames = new Set();
  let valid =
    categories.length > 0 && categories.length <= 20 && coaches.length <= 20;
  const normalizedCategories = categories.slice(0, 20).map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      valid = false;
      return null;
    }
    const category =
      typeof item.category === 'string'
        ? item.category.trim()
        : '';
    const normalizedName = category.toLowerCase();
    if (!category || category.length > 100 || categoryNames.has(normalizedName)) valid = false;
    categoryNames.add(normalizedName);
    const price = (value) => {
      if (!isNumericInput(value)) {
        valid = false;
        return null;
      }
      const amount = Number(value);
      if (!Number.isFinite(amount) || amount <= 0 || amount > 99999999.99) {
        valid = false;
        return null;
      }
      return amount;
    };
    const yearlyDiscountType = item.yearlyDiscountType;
    let yearlyDiscountValue = null;
    if (yearlyDiscountType === 'freeMonths') {
      if (!isNumericInput(item.yearlyDiscountValue)) valid = false;
      const amount = Number(item.yearlyDiscountValue);
      if (!Number.isInteger(amount) || amount < 1 || amount > 11) valid = false;
      else yearlyDiscountValue = amount;
    } else if (yearlyDiscountType === 'percentage') {
      if (!isNumericInput(item.yearlyDiscountValue)) valid = false;
      const amount = Number(item.yearlyDiscountValue);
      if (!Number.isFinite(amount) || amount <= 0 || amount > 100) valid = false;
      else yearlyDiscountValue = amount;
    } else if (yearlyDiscountType !== 'none') {
      valid = false;
    }
    return {
      category,
      sessionPrice: price(item.sessionPrice),
      monthlyPrice: price(item.monthlyPrice),
      yearlyPrice: price(item.yearlyPrice),
      yearlyDiscountType,
      yearlyDiscountValue,
    };
  });
  const coachNames = new Set();
  const normalizedCoaches = coaches.slice(0, 20).map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      valid = false;
      return null;
    }
    const name =
      typeof item.name === 'string' ? item.name.trim() : '';
    if (!name || name.length > 100 || coachNames.has(name.toLowerCase())) valid = false;
    coachNames.add(name.toLowerCase());
    if (!isNumericInput(item.monthlyPrice)) valid = false;
    const monthlyPrice = Number(item.monthlyPrice);
    if (
      !Number.isFinite(monthlyPrice) ||
      monthlyPrice <= 0 ||
      monthlyPrice > 99999999.99
    ) {
      valid = false;
    }
    const profileImageUrl =
      item.profileImageUrl == null
        ? null
        : typeof item.profileImageUrl === 'string'
          ? item.profileImageUrl
          : '';
    if (
      profileImageUrl !== null &&
      (profileImageUrl.length > 400000 ||
        !/^(data:image\/(?:jpeg|png|webp);base64,|https?:\/\/)/i.test(
          profileImageUrl,
        ))
    ) {
      valid = false;
    }
    return { name, monthlyPrice, profileImageUrl };
  });
  return {
    valid,
    categories: normalizedCategories.filter(Boolean),
    coaches: normalizedCoaches.filter(Boolean),
  };
}

async function saveFitnessDetails(
  executor,
  businessId,
  body,
  details = fitnessDetailsFromBody(body),
) {
  if (body.businessType !== 'Fitness & Wellness') {
    await executor.execute(
      'DELETE FROM fitness_business_details WHERE business_id = ?',
      [businessId],
    );
    return;
  }
  await executor.execute(
    `INSERT INTO fitness_business_details
       (business_id, fitness_categories_json, fitness_coaches_json)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE
       fitness_categories_json = VALUES(fitness_categories_json),
       fitness_coaches_json = VALUES(fitness_coaches_json)`,
    [
      businessId,
      JSON.stringify(details.categories),
      JSON.stringify(details.coaches),
    ],
  );
}

module.exports = {
  fitnessDetailsFromBody,
  saveEventDetails,
  saveFitnessDetails,
};
