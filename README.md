# thai-quotation — Claude Code Plugin Marketplace

Marketplace สำหรับปลั๊กอิน **thai-quotation** — สร้างใบเสนอราคา (Quotation) ภาษาไทยเป็นไฟล์ HTML
พร้อมพิมพ์เป็น PDF คำนวณ VAT 7% และจำนวนเงินตัวอักษรอัตโนมัติ

## วิธีติดตั้ง

ใน Claude Code:

```
/plugin marketplace add vitoon-ai/thai-quotation
/plugin install thai-quotation@boombignose-local
```

จากนั้นรีโหลด session แล้วใช้คำสั่ง `/quotation` ได้เลย

## มีอะไรใน marketplace นี้

| Plugin | คำสั่ง | รายละเอียด |
|---|---|---|
| `thai-quotation` | `/quotation` | สร้างใบเสนอราคาภาษาไทย (HTML → PDF), VAT 7%, จำนวนเงินตัวอักษร |

เอกสารการใช้งานเต็ม: [plugins/thai-quotation/README.md](plugins/thai-quotation/README.md)

## โครงสร้าง

```
.claude-plugin/marketplace.json     # นิยาม marketplace (id: boombignose-local)
plugins/thai-quotation/             # ตัวปลั๊กอิน
  .claude-plugin/plugin.json
  commands/quotation.md
  templates/quotation.html
  examples/
  README.md
```
