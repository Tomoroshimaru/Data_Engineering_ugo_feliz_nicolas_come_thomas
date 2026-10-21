# Data dictionary, v1

Every table landed in bronze, `gs://data-engineering-i2-toes-futcn/bronze/<table>/ingest_date=YYYY-MM-DD/`,
from the company export (Albert's Marketplace, release v1.0.0), first landed on
2026-10-20.

**Type.** Bronze stores every value as the exact string the export wrote
([ADR-0002](adr/0002-bronze-layout.md)), so every column is `STRING` in bronze.
The *intended type* column is what silver will cast it to.

**Personal data.** One of:

- **Secret**: credentials or card data. Never ingested.
- **Yes**: identifies or locates a person directly (name, address, phone).
- **Pseudonymous**: an identifier that points to a person through another table.
- **Possible**: free text a person wrote, which may contain anything.
- **No**.

`unnamed_0` is the export's unnamed index column, kept and given a name.

## Not landed: tables holding secrets

| Table | Column | Intended type | Meaning | Personal data |
|---|---|---|---|---|
| `customer` | `c_id` | string | Customer identifier | Pseudonymous |
| | `fname`, `lname` | string | First and last name | Yes |
| | `phone` | string | Phone number | Yes |
| | `email` | string | Email address | Yes |
| | `pwd` | string | Account password | **Secret** |
| `payment_details` | `payment_id` | integer | Payment method identifier | Pseudonymous |
| | `card_no` | string | Card number | **Secret** |
| | `cvv` | string | Card security code | **Secret** |
| | `expiry_date` | string | Card expiry date | Yes (card data) |
| | `billing_address` | string | Billing address | Yes |

Both stay at the source. Lesson 3's extraction reads `customer` without `pwd`,
and `payment_details` without `card_no` and `cvv`.

## Orders and payments

| Table | Column | Intended type | Meaning | Personal data |
|---|---|---|---|---|
| `orders` (222,644 rows) | `unnamed_0` | integer | Export index | No |
| | `order_id` | integer | Order identifier. Each original (`<= 111322`) has a duplicated twin | No |
| | `buyer_id` | string | Customer who placed the order | Pseudonymous |
| | `discount_id` | integer | Discount code used. Empty on every row | No |
| | `payment_id` | integer | Payment method used | Pseudonymous |
| | `order_date` | date | Day the order was placed | No |
| `order_items` (408,560) | `order_id` | integer | Order the line belongs to | No |
| | `p_id` | string | Product | No |
| | `qty` | integer | Units ordered | No |
| | `price_at_purchase` | numeric | Unit price paid | No |
| `payment` (222,644) | `transaction_id` | string | Payment transaction | No |
| | `order_id` | integer | Order paid | No |
| | `payment_id` | integer | Payment method used | Pseudonymous |
| | `amount` | numeric | Amount paid | No |
| | `method` | string | Payment method. Always `Credit Card` | No |
| | `status` | string | Always `completed` | No |
| | `created_at` | timestamp | When the payment was made | No |
| `customer_payment` (100,000) | `unnamed_0` | integer | Export index | No |
| | `payment_id` | integer | Payment method | Pseudonymous |
| | `c_id` | string | Customer who owns it | Pseudonymous |
| | `is_default` | boolean | Default payment method. Always `1` | No |
| `discount` (0 rows) | `unnamed_0`, `discount_id`, `discount_name`, `d_desc`, `discount_amt` | | Discount codes. Empty in this export | No |
| `returns` (0 rows) | `unnamed_0`, `return_id`, `buyer_id`, `p_id`, `order_id` | | Returned products. Empty in this export | `buyer_id`: Pseudonymous |

## Customers and addresses

| Table | Column | Intended type | Meaning | Personal data |
|---|---|---|---|---|
| `buyer` (100,000) | `unnamed_0` | integer | Export index | No |
| | `buyer_id` | string | Customer who has bought | Pseudonymous |
| `customer_shipping` (200,001) | `unnamed_0` | integer | Export index | No |
| | `address_id` | integer | Address | Pseudonymous |
| | `c_id` | string | Customer | Pseudonymous |
| | `is_default` | boolean | Default shipping address (one per customer) | No |
| `shipping_details` (200,001) | `unnamed_0` | integer | Export index | No |
| | `address_id` | integer | Address | Pseudonymous |
| | `street_address` | string | Street and number | **Yes** |
| | `city` | string | City | **Yes** |
| | `state` | string | Region (83 values) | **Yes** |
| | `zip` | string | Postcode | **Yes** |
| | `country` | string | Country (6 values) | **Yes** |
| | `phone` | string | Phone number, with leading zero | **Yes** |
| `subscription` (50,091) | `unnamed_0` | integer | Export index | No |
| | `subscription_id` | integer | Subscription | No |
| | `c_id` | string | Subscribed customer | Pseudonymous |
| | `start_date`, `end_date` | date | Subscription period | No |
| `wishlist_item` (24,810) | `unnamed_0` | integer | Export index | No |
| | `product_id` | string | Product wished for (same values as `p_id`) | No |
| | `buyer_id` | string | Customer | Pseudonymous |
| `cart` (0 rows) | `unnamed_0`, `cart_id`, `buyer_id`, `total_qty`, `total_price` | | Shopping carts. Empty in this export | `buyer_id`: Pseudonymous |
| `cart_items` (0 rows) | `unnamed_0`, `cart_id`, `p_id`, `qty` | | Cart lines. Empty in this export | No |

## Products and sellers

| Table | Column | Intended type | Meaning | Personal data |
|---|---|---|---|---|
| `product` (42,858) | `unnamed_0` | integer | Export index | No |
| | `p_id` | string | Product identifier | No |
| | `p_name`, `p_desc` | string | Name and description | No |
| | `price` | numeric | Current list price | No |
| | `qty` | integer | Stock | No |
| | `category_id` | integer | Category (1 or 2) | No |
| `category` (2) | `unnamed_0`, `category_id`, `name`, `c_desc` | | `All Beauty`, `Premium Beauty` | No |
| `product_images` (186,837) | `unnamed_0` | integer | Export index | No |
| | `p_id` | string | Product | No |
| | `p_image` | string | Image URL | No |
| `daily_deals` (0 rows) | `p_id`, `deal_date`, `discount` | | Daily deals. Empty in this export | No |
| `seller` (30,766) | `unnamed_0` | integer | Export index | No |
| | `seller_id` | string | Seller | No |
| | `seller_type` | string | `marketplace` or `third_party_seller` | No |
| | `seller_name` | string | Seller name. Empty on every row | Yes, if filled (a seller can be a person) |
| `seller_products` (46,593) | `unnamed_0`, `seller_id`, `p_id` | | Which seller lists which product | No |

## Reviews

| Table | Column | Intended type | Meaning | Personal data |
|---|---|---|---|---|
| `review` (111,322) | `unnamed_0` | integer | Export index | No |
| | `review_id` | integer | Review | No |
| | `buyer_id` | string | Customer who wrote it | Pseudonymous |
| | `r_desc` | string | Review text. 14 empty, 110 a single space | **Possible** (free text) |
| | `title` | string | Review title | **Possible** (free text) |
| | `rating` | integer | 1 to 5 | No |
| | `seller_product_flag` | string | Always `S` | No |
| `product_reviews` (111,322) | `unnamed_0`, `p_id`, `review_id` | | Which product each review is about | No |
| `seller_reviews` (111,322) | `unnamed_0`, `seller_id`, `review_id` | | Which seller each review is about | No |
| `review_images` (119,382) | `unnamed_0` | integer | Export index | No |
| | `review_id` | integer | Review | No |
| | `review_img` | string | Image URL posted with the review | **Possible** (a customer's photo) |

## Shipping

| Table | Column | Intended type | Meaning | Personal data |
|---|---|---|---|---|
| `shipment` (408,560) | `unnamed_0` | integer | Export index | No |
| | `shipping_id` | integer | Shipment | No |
| | `order_id`, `p_id` | | Order line shipped | No |
| | `carrier_id` | integer | Carrier | No |
| | `shipment_type` | string | Always `NP` | No |
| | `status` | string | `delivered`, `in_transit` or `processing` | No |
| | `est_delivery_date` | date | Promised delivery date | No |
| | `actual_delivery_date` | date | Delivery date. Empty while not delivered (3,881 rows) | No |
| `carrier` (4) | `unnamed_0`, `carrier_id`, `carrier_name` | | Four carriers, by name | No |
