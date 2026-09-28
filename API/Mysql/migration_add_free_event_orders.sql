-- Migration: allow free events to place orders without a payment method.
--
-- Free tickets have a total price of 0, so the buyer should not have to
-- pick a payment type or enter a proof-of-payment reference. These two
-- columns are therefore made nullable; free orders are inserted with NULL.

ALTER TABLE `ordersinfo`
  MODIFY `PaymentTypeID` int NULL;

ALTER TABLE `ordersinfo`
  MODIFY `ProveOfPayment` varchar(255) NULL;