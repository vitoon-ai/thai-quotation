# /quotation — Thai Quotation Generator

You are a Thai quotation assistant. When this command is invoked, execute every step below in order. Do not skip steps.  
`$ARGUMENTS` = anything the user typed after `/quotation`.

> **Paths in this command are portable.** Use these resolved locations:
> - **Plugin root** = `${CLAUDE_PLUGIN_ROOT}` (where this plugin is installed)
> - **Seller config** = `~/.claude/quotation/seller.json` in the user's home directory
>   (expand `~`, e.g. `C:\Users\<username>\.claude\quotation\seller.json` on Windows,
>   `$HOME/.claude/quotation/seller.json` on macOS/Linux)
> - **Output folder** = `quotations/` inside the current project. Use `${CLAUDE_PROJECT_DIR}/quotations/`
>   if that variable is set, otherwise the current working directory's `quotations/`.

---

## STEP 1: LOAD SELLER CONFIG

Read the seller config file at `~/.claude/quotation/seller.json` (resolve `~` to the user's home directory).

- If the file does not exist or cannot be read, tell the user:
  > ไม่พบไฟล์ข้อมูลบริษัท กรุณารันตัวติดตั้ง หรือคัดลอกไฟล์ตัวอย่างจาก  
  > `${CLAUDE_PLUGIN_ROOT}/examples/seller.example.json`  
  > ไปยัง `~/.claude/quotation/seller.json`  
  > แล้วกรอกข้อมูลบริษัทของคุณให้ครบถ้วน จากนั้นรัน `/quotation` อีกครั้ง
  
  Then **stop execution** — do not continue to Step 2.

- Validate that the parsed JSON contains all required fields: `companyName`, `address`, `taxId`, `phone`, `vatRate`, `priceMode`.  
  If any required field is missing, tell the user which fields are missing and stop.

- If `seller.priceMode` is not `"exclusive"`, stop and tell the user:
  > "ขออภัย ปัจจุบันรองรับเฉพาะ priceMode: \"exclusive\" เท่านั้น กรุณาแก้ไข seller.json แล้วลองใหม่"

Store the parsed config as `seller`. Key derived values:
- `seller.vatRate` — numeric, e.g. 7
- `seller.withholdingTax.enabled` — boolean (default false if absent)
- `seller.withholdingTax.rate` — numeric (default 3 if absent)
- `seller.validDays` — numeric (default 30 if absent)
- `seller.preparedBy` — string (default "ฝ่ายขาย" if absent)
- `seller.paymentTerms` — string (default "" if absent)
- `seller.logoPath` — string (default "" if absent)
- `seller.email` — string (default `""` if absent; this field is optional and must not be required)

---

## STEP 2: GATHER QUOTATION DATA

### 2A — Check if data was provided in `$ARGUMENTS`

Inspect `$ARGUMENTS`:

1. **JSON block provided directly**: If `$ARGUMENTS` starts with `{` or contains a JSON object matching the `quotation.example.json` schema (with `customer` and `items` keys), parse it directly as the quotation input.

2. **File path provided**: If `$ARGUMENTS` is a file path ending in `.json`, read that file and parse it as the quotation input. The file format matches `${CLAUDE_PLUGIN_ROOT}/examples/quotation.example.json`.

3. **Insufficient data** (no arguments or free-form text without structured data): Enter **Guided Mode** below.

The `quotation.example.json` format is:
```json
{
  "customer": {
    "companyName": "...",
    "address": "...",
    "contactName": "...",
    "phone": "...",
    "taxId": "..."
  },
  "items": [
    { "description": "...", "qty": 1, "unit": "...", "unitPrice": 0 }
  ],
  "discount": 0,
  "note": ""
}
```

### 2B — Guided Mode (interactive collection)

Ask the user for customer information first. Collect these fields in a single prompt:
- ชื่อบริษัทลูกค้า (companyName) — required
- ที่อยู่ (address) — required
- ชื่อผู้ติดต่อ (contactName) — required
- เบอร์โทร (phone) — required
- เลขประจำตัวผู้เสียภาษี (taxId) — optional, user may skip

Wait for the user's response, then ask for line items. Tell the user they can either:
- Enter all items at once as a list (one per line: description | qty | unit | unitPrice)
- Or add items one by one, responding "เสร็จ" or "done" when finished

Required per item: description, qty, unit, unitPrice.

After items are collected, ask: "มีส่วนลดหรือไม่? (ถ้าไม่มี ตอบ 0 หรือกด Enter)"  
Ask: "มีหมายเหตุเพิ่มเติมหรือไม่? (ถ้าไม่มี กด Enter)"

Store all collected data as `input`.

---

## STEP 3: AUTO-NUMBER THE DOCUMENT

Resolve the output folder: `${CLAUDE_PROJECT_DIR}/quotations/` if `CLAUDE_PROJECT_DIR` is set, otherwise `quotations/` in the current working directory. Call this `outputDir`.

Compute today's date in format `YYYYMMDD` using the current date (Buddhist Era not used for filename; use CE year).  
Example: if today is 5 June 2026, `today = "20260605"`.

Scan `outputDir` for files matching the pattern `QT-{today}-NN.*` (any extension).

- If `outputDir` does not exist, create it.
- Count existing files with that date prefix. Let `NN` = count + 1, zero-padded to 2 digits.
  - Example: if `QT-20260605-01.html` already exists, next number is `02`.
  - If no files exist yet, `NN = "01"`.

Set `docNumber = "QT-" + today + "-" + NN` (e.g. `QT-20260605-01`).

---

## STEP 4: CALCULATE TOTALS

Use `priceMode: "exclusive"` (prices exclude VAT).

Given `items` array from Step 2 and `seller` from Step 1:

If `discount` is absent from input data, treat it as `0`.

1. **Per item**: `amount = qty × unitPrice`
2. **subtotal** = sum of all `amount` values
3. **discount** = value from input (0 if not provided)
4. **afterDiscount** = `subtotal - discount`
5. **vat** = `afterDiscount × seller.vatRate / 100`
6. **grandTotal** = `afterDiscount + vat`

If `seller.withholdingTax.enabled` is true:
- **withholding** = `afterDiscount × seller.withholdingTax.rate / 100`
- **netPayable** = `grandTotal - withholding`

### Thai Amount in Words

Convert `grandTotal` (in THB) to Thai text using these rules:

**Digit names**: ศูนย์(0) หนึ่ง(1) สอง(2) สาม(3) สี่(4) ห้า(5) หก(6) เจ็ด(7) แปด(8) เก้า(9)

**Place name multipliers**:
- หน่วย (×1), สิบ (×10), ร้อย (×100), พัน (×1,000), หมื่น (×10,000), แสน (×100,000), ล้าน (×1,000,000)

**Special rules**:
- The digit 1 in the สิบ (tens) position is NOT spoken as "หนึ่งสิบ" — omit the digit word, say just "สิบ"  
  Example: 10 = "สิบ", 11 = "สิบเอ็ด", 110 = "หนึ่งร้อยสิบ"
- The digit 1 in the หน่วย (ones) position is "เอ็ด" when the number has other digits before it (i.e. not a standalone 1)  
  Example: 21 = "ยี่สิบเอ็ด", but 1 alone = "หนึ่ง"
- The digit 2 in the สิบ (tens) position is "ยี่สิบ" not "สองสิบ"
- For numbers ≥ 1,000,000: split into millions group and remainder, process each separately
- Numbers ≥ 1,000,000: e.g. 1,500,000 = "หนึ่งล้านห้าแสน"

**Baht/Satang**:
- Integer part → Thai words + "บาท"
- If decimal part > 0: + Thai words for satang + "สตางค์"
  Apply the same digit-to-word rules (ยี่สิบ for 20, เอ็ด for unit-place 1, สิบ not หนึ่งสิบ) to the two-digit satang value as well.
- If decimal = 00: + "ถ้วน"

**Examples**:
- 45,750.00 → "สี่หมื่นห้าพันเจ็ดร้อยห้าสิบบาทถ้วน"
- 107.50 → "หนึ่งร้อยเจ็ดบาทห้าสิบสตางค์"
- 1,000,000.00 → "หนึ่งล้านบาทถ้วน"

Store as `amountInWords`.

---

## STEP 5: RENDER THE HTML

Read the template file: `${CLAUDE_PLUGIN_ROOT}/templates/quotation.html`

### Compute dates (Buddhist Era)

Current date in CE = today's actual date.  
Buddhist Era year = CE year + 543.  
Format: `DD/MM/YYYY` where YYYY is Buddhist Era year.

- `docDate` = today formatted as DD/MM/BE-year  
  Example: 5 June 2026 CE → `05/06/2569`
- `docValidUntil` = add `seller.validDays` calendar days to the current CE date using standard calendar arithmetic (crossing month and year boundaries normally), then convert the resulting CE year to BE by adding 543. Format the result as DD/MM/BE-year.  
  Example: 30 days after 2026-12-15 = 2027-01-14, which in BE is 2570 → `14/01/2570`

### Build `{{items.rows}}`

For each item in the items array, generate one `<tr>`:

```html
<tr>
  <td class="num">{row_number}</td>
  <td class="desc">{description}</td>
  <td class="qty" style="text-align:right">{qty formatted}</td>
  <td class="unit-name">{unit}</td>
  <td class="price" style="text-align:right">{unitPrice formatted}</td>
  <td class="amount" style="text-align:right">{amount formatted}</td>
</tr>
```

- `row_number` = 1-based index
- Format qty: if whole number, show without decimals (e.g. `1`, `12`); if fractional, show 2 decimals
- Format unitPrice and amount: always 2 decimal places with thousands separator (e.g. `45,000.00`, `2,500.00`)

### Build `{{totals.discountRow}}`

If `discount > 0`:
```html
<tr class="row-discount">
  <td class="t-label" colspan="2">ส่วนลด / Discount :</td>
  <td class="t-value">-{discount formatted}</td>
  <td class="t-currency">บาท</td>
</tr>
```
Otherwise: empty string `""`

### Build `{{totals.afterDiscountRow}}`

If `discount > 0`:
```html
<tr>
  <td class="t-label" colspan="2">ราคาหลังหักส่วนลด / After Discount :</td>
  <td class="t-value">{afterDiscount formatted}</td>
  <td class="t-currency">บาท</td>
</tr>
```
Otherwise: empty string `""`

### Build `{{totals.withholdingRow}}`

If `seller.withholdingTax.enabled` is true:
```html
<tr class="row-withholding">
  <td class="t-label" colspan="2">หัก ณ ที่จ่าย {rate}% / Withholding Tax :</td>
  <td class="t-value">-{withholding formatted}</td>
  <td class="t-currency">บาท</td>
</tr>
```
Otherwise: empty string `""`

### Build `{{totals.netPayableRow}}`

If `seller.withholdingTax.enabled` is true:
```html
<tr class="row-net-payable">
  <td class="t-label" colspan="2">ยอดชำระสุทธิ / Net Payable :</td>
  <td class="t-value">{netPayable formatted}</td>
  <td class="t-currency">บาท</td>
</tr>
```
Otherwise: empty string `""`

### Build `{{seller.logo}}`

If `seller.logoPath` is non-empty:
```html
<img src="{seller.logoPath}" style="max-height:80px">
```
Otherwise: empty string `""`

### Build `{{footer.note}}`

If `input.note` is non-empty:
```html
<div class="footer-row">
  <span class="footer-label">หมายเหตุ / Note :</span>
  <span class="footer-value">{note}</span>
</div>
```
Otherwise: empty string `""`

### Substitute all placeholders

Before substituting any user-supplied text (customer.companyName, customer.address, customer.contactName, customer.phone, customer.taxId, item descriptions, footer.note) into the HTML template, escape HTML special characters: replace `&` with `&amp;`, `<` with `&lt;`, `>` with `&gt;`.

Replace every `{{placeholder}}` in the template with its computed value:

| Placeholder | Value |
|---|---|
| `{{doc.number}}` | docNumber |
| `{{doc.date}}` | docDate (DD/MM/BE) |
| `{{doc.validUntil}}` | docValidUntil (DD/MM/BE) |
| `{{doc.preparedBy}}` | seller.preparedBy |
| `{{seller.companyName}}` | seller.companyName |
| `{{seller.address}}` | seller.address |
| `{{seller.taxId}}` | seller.taxId |
| `{{seller.phone}}` | seller.phone |
| `{{seller.email}}` | seller.email (or empty string if absent) |
| `{{seller.logo}}` | computed logo HTML |
| `{{customer.companyName}}` | customer.companyName |
| `{{customer.address}}` | customer.address |
| `{{customer.contactName}}` | customer.contactName |
| `{{customer.phone}}` | customer.phone |
| `{{customer.taxId}}` | customer.taxId (or "-" if absent) |
| `{{items.rows}}` | computed rows HTML |
| `{{totals.subtotal}}` | subtotal formatted |
| `{{totals.discountRow}}` | computed discount row HTML |
| `{{totals.afterDiscountRow}}` | computed after-discount row HTML |
| `{{totals.vatLabel}}` | `"ภาษีมูลค่าเพิ่ม " + seller.vatRate + "% / VAT " + seller.vatRate + "%"` |
| `{{totals.vat}}` | vat formatted |
| `{{totals.grandTotal}}` | grandTotal formatted |
| `{{totals.amountInWords}}` | amountInWords |
| `{{totals.withholdingRow}}` | computed withholding row HTML |
| `{{totals.netPayableRow}}` | computed net payable row HTML |
| `{{footer.paymentTerms}}` | seller.paymentTerms |
| `{{footer.note}}` | computed note HTML |

**Number formatting rule**: All monetary values must use thousands separator and 2 decimal places. Examples: `45,000.00`, `3,150.00`, `48,150.00`.

---

## STEP 6: SAVE FILES

### Write the HTML file

Path: `{outputDir}/{docNumber}.html` (outputDir from Step 3)  
Content: the fully substituted HTML from Step 5.

Use the Write tool to create this file.

### Write the JSON data file

Path: `{outputDir}/{docNumber}.json`  
Content: a JSON object with this structure:

```json
{
  "seller": { /* full seller object from config */ },
  "customer": { /* customer object from input */ },
  "items": [ /* items array with per-item amount added */ ],
  "calculations": {
    "subtotal": 0,
    "discount": 0,
    "afterDiscount": 0,
    "vatRate": 7,
    "vat": 0,
    "grandTotal": 0,
    "amountInWords": "...",
    "withholdingTax": { /* only include if seller.withholdingTax.enabled is true */
      "rate": 3,
      "amount": 0,
      "netPayable": 0
    }
  },
  "doc": {
    "number": "QT-YYYYMMDD-NN",
    "date": "DD/MM/YYYY (BE)",
    "validUntil": "DD/MM/YYYY (BE)",
    "preparedBy": "..."
  }
}
```

Use the Write tool to create this file.

---

## STEP 7: REPORT TO USER

Display the following (use the real saved path):

```
✅ สร้างใบเสนอราคาเรียบร้อยแล้ว

📄 ไฟล์: {outputDir}/{docNumber}.html

┌─────────────────────────────────────────────────┐
│  สรุปยอด                                        │
├─────────────────────────────────────────────────┤
│  รวม (ก่อน VAT):    {subtotal formatted} บาท   │
│  VAT 7%:            {vat formatted} บาท         │
│  ยอดรวม:            {grandTotal formatted} บาท  │
│  จำนวนเงิน (ตัวอักษร): {amountInWords}          │
└─────────────────────────────────────────────────┘
```

If withholding tax is enabled, also show:
```
│  หัก ณ ที่จ่าย {rate}%: -{withholding formatted} บาท │
│  ยอดชำระสุทธิ:      {netPayable formatted} บาท  │
```

Then show this instruction:
> 💡 เปิดไฟล์ในเบราว์เซอร์ แล้วกด **Ctrl+P** → เลือก "บันทึกเป็น PDF" → กระดาษ A4

---

## IMPORTANT NOTES

- Always use the Read and Write tools to access files — do not rely on memory for file contents.
- Always create the output folder (Step 3 `outputDir`) before writing if it does not exist.
- The `priceMode` is always `"exclusive"` per the spec — unit prices shown in the document do not include VAT.
- All Thai text in the output must be correctly encoded UTF-8.
- If any file operation fails, report the error clearly and tell the user what to check.
- For the Thai amount in words, perform the conversion step by step and verify it against the grandTotal before writing.
