# Bug 67: FlexPassOffer Decimal Values for Payout Fields

## Issue Description
FlexPassOffers don't allow decimal values for payout info values like flat payout, spiff and facility fee. These fields should allow for decimal values and be handled like currency in general, the same as the "Price" field.

## Analysis Summary

The issue is that `facility_fee`, `spiff`, and `flat_payout` fields in FlexPassOffer were created as decimal columns without specifying a scale, which defaults to 0 in MySQL, preventing decimal values. Additionally, the `price` field uses float type which can cause precision issues with currency.

### Key Findings:

1. **Database Schema Issues**:
   - Price field: Defined as `float` (can cause precision issues)
   - Payout fields: Defined as `decimal(10)` with no scale (defaults to 0, no decimal places)

2. **Validation Gaps**:
   - Price field: Has numericality and presence validations
   - Payout fields: Have NO validations

3. **Display Issues**:
   - No currency formatting in views
   - Payout fields not shown in show view
   - No use of `to_currency` helper

## Plan to Fix Currency Handling for FlexPassOffer

### 1. **Create RSpec Model Tests** (Test-First Approach)
Create `spec/models/flex_pass_offer_spec.rb`:
- Test that price, facility_fee, spiff, and flat_payout can accept decimal values
- Test validation for numericality and non-negative values
- Test proper decimal precision (2 decimal places)
- Test currency formatting methods

### 2. **Create Controller Tests**
Create `spec/controllers/admin/flex_pass_offers_controller_spec.rb`:
- Test that decimal values are properly saved through the controller
- Test that invalid values (non-numeric) are rejected
- Test proper parameter handling for currency fields

### 3. **Create Feature/Integration Tests**
Update or create Cucumber tests:
- Test entering decimal values in the form (e.g., "10.50")
- Test that decimal values display correctly after saving
- Test edge cases (0.01, 999999.99)

### 4. **Database Migration**
Create migration to fix column types:
- Change `price` from float to decimal(8,2)
- Change `facility_fee` from decimal(10) to decimal(8,2)
- Change `spiff` from decimal(10) to decimal(8,2)
- Change `flat_payout` from decimal(10) to decimal(8,2)

### 5. **Model Updates**
Update `app/models/flex_pass_offer.rb`:
- Add validations for numericality
- Add validations for non-negative values
- Consider adding monetize declarations if using money-rails

### 6. **View Updates**
- Update form to use currency input type or add step="0.01" to number fields
- Update show view to display all payout fields
- Use `to_currency` helper for all monetary displays

### 7. **Decorator Updates**
Update `app/decorators/flex_pass_offer_decorator.rb`:
- Add methods to format facility_fee, spiff, and flat_payout as currency
- Ensure consistent formatting across the application

### 8. **Testing & Verification**
- Run all tests to ensure nothing breaks
- Manually test decimal value entry and display
- Verify reports correctly handle decimal values
- Check for any JavaScript validation that might need updating

### 9. **Data Migration (if needed)**
- Check if any existing data needs conversion
- Create data migration if float-to-decimal conversion causes issues

## Implementation Notes

This plan follows test-first methodology and ensures consistent currency handling across the FlexPassOffer model, matching the patterns used elsewhere in the application (decimal columns with precision 8, scale 2, and use of `to_currency` helper for display).