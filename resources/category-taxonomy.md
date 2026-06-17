# Amazon Category Taxonomy

Fixed top-level category labels used for every daily report. Always map a product into exactly one
of these labels (pick the closest fit) so labels and colors stay consistent day over day, making
category pills and the category bar chart comparable across reports. Each has a fixed hex color —
reuse these exact values in the dashboard, never invent new ones.

| Category | Hex Color |
|---|---|
| Electronics | #2563eb |
| Home & Kitchen | #16a34a |
| Beauty & Personal Care | #db2777 |
| Toys & Games | #f59e0b |
| Health & Household | #0d9488 |
| Grocery | #65a30d |
| Apparel | #7c3aed |
| Sports & Outdoors | #ea580c |
| Pet Supplies | #92400e |
| Tools & Home Improvement | #475569 |
| Office Products | #0891b2 |
| Baby | #e11d48 |

If a product genuinely doesn't fit any label above, use "Other" with color `#64748b` — but treat this
as a last resort and reconsider whether it actually fits Home & Kitchen or Electronics first, since
most consumer products map cleanly onto one of the twelve labels.
