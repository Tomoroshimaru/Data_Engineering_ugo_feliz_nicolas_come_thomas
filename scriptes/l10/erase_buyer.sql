-- Erase one buyer from the warehouse tables dbt reads (l04_fl), in one transaction.
-- What is about the person goes (address, phone, reviews); the sales stay, unlinked,
-- so revenue in the marts does not change.
DECLARE b STRING DEFAULT 'AE224QB4K4PDIZ6FVU6MGVFEYSPQ';

BEGIN TRANSACTION;

-- The address is found through customer_shipping, so it goes first.
DELETE FROM `data-engineering-i2.l04_fl.shipping_details`
WHERE address_id IN (SELECT address_id FROM `data-engineering-i2.l04_fl.customer_shipping` WHERE c_id = b);

DELETE FROM `data-engineering-i2.l04_fl.customer_shipping` WHERE c_id = b;

DELETE FROM `data-engineering-i2.l04_fl.product_reviews`
WHERE review_id IN (SELECT review_id FROM `data-engineering-i2.l04_fl.review` WHERE buyer_id = b);

DELETE FROM `data-engineering-i2.l04_fl.review` WHERE buyer_id = b;

-- The orders stay for the accounts, without anyone attached.
UPDATE `data-engineering-i2.l04_fl.orders` SET buyer_id = 'ERASED' WHERE buyer_id = b;

COMMIT TRANSACTION;
