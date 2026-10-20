# Data flows

One row per flow: where the data comes from, what it is, who uses it, how often
it moves, and in which format.

| # | Source | Data | Consumer | Frequency | Format | Notes |
|---|---|---|---|---|---|---|
| 1 | Web shop (checkout) | Orders, order lines, payments, saved cards, stock | PostgreSQL database | Continuous | Database writes | Personal and payment data |
| 2 | Web shop (accounts) | Customers, addresses, passwords | PostgreSQL database | Continuous | Database writes | Personal data and credentials |
| 3 | Web shop (reviews) | Ratings, review texts, photo links | PostgreSQL database | Continuous | Database writes | Each review is tied to a buyer |
| 4 | Web shop (browsing) | Clickstream events (page views, add to cart) | Kafka topic `clickstream` | Continuous | JSON events | Each event carries a `buyer_id` |
| 5 | PostgreSQL database | Orders, customers, products | Analysts | On demand | SQL queries | Run against the tables checkout writes to |
| 6 | PostgreSQL database | Selected tables | Analysts' spreadsheets | Nightly | CSV export | Opened and reworked by hand |
| 7 | *(wanted)* | Units sold per product, per country, per day | ML team | Daily | Does not exist yet | See [the star schema sketch](model/star-daily-demand.md) |

## Under the matrix, answer

- **Which flows carry personal data?** Flows 1 and 2 (names, addresses, phone numbers, saved cards, passwords), flow 3 (each review is attached to a buyer), flow 4 (each click carries a `buyer_id`), and flows 5 and 6, which read and copy those same tables. The saved cards and passwords should never leave the source.
- **Which consumers read directly from a system that also serves customers?** The analysts (flow 5) query the production PostgreSQL database, and the nightly export (flow 6) reads it too. Every heavy report runs on the database the checkout writes to.
- **Where could the same figure be computed twice, in two different ways?** Revenue: once in the analysts' SQL (flow 5) and once in the spreadsheets built from the CSV export (flow 6). Orders are duplicated in the source, and each report handles the duplicates its own way, which is why the reports disagree on revenue.
