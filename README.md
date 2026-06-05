# thai-quotation — Claude Code Plugin Marketplace

Marketplace สำหรับปลั๊กอิน **thai-quotation** — สร้างใบเสนอราคา (Quotation) ภาษาไทยเป็นไฟล์ HTML
พร้อมพิมพ์เป็น PDF คำนวณ VAT 7% และจำนวนเงินตัวอักษรอัตโนมัติ

## วิธีติดตั้ง

### ทางเลือก A — ตัวติดตั้งอัตโนมัติ (Windows · แนะนำ)

เปิด **PowerShell** แล้วรันบรรทัดเดียว:

```powershell
irm https://raw.githubusercontent.com/vitoon-ai/thai-quotation/main/install.ps1 | iex
```

ตัวติดตั้งจะ: ดาวน์โหลด marketplace → ลงทะเบียน → ติดตั้งปลั๊กอิน → เปิดใช้งาน →
สร้างไฟล์ `seller.json` ให้พร้อมแก้ไข (สำรอง config เดิมทุกครั้ง และรันซ้ำได้)

> ต้องมี [git](https://git-scm.com) ในเครื่อง · ลองแบบไม่เขียนจริงด้วย `-DryRun` ได้
> โดยโหลดสคริปต์มาเก็บไว้ก่อน:
> ```powershell
> irm https://raw.githubusercontent.com/vitoon-ai/thai-quotation/main/install.ps1 -OutFile install.ps1; .\install.ps1 -DryRun
> ```

หลังติดตั้งเสร็จ ให้ **รีโหลด Claude Code** แล้วใช้คำสั่ง `/quotation` ได้เลย

### ทางเลือก B — ติดตั้งด้วยมือใน Claude Code

```
/plugin marketplace add vitoon-ai/thai-quotation
/plugin install thai-quotation@boombignose-local
```

จากนั้นคัดลอก `plugins/thai-quotation/examples/seller.example.json`
ไปไว้ที่ `~/.claude/quotation/seller.json` แล้วกรอกข้อมูลบริษัทของคุณ

## ตั้งค่า & ที่เก็บไฟล์ (v1.1.0+)

- **ข้อมูลผู้ขาย:** `~/.claude/quotation/seller.json` (เช่น `C:\Users\<you>\.claude\quotation\seller.json`)
- **ใบเสนอราคาที่สร้าง:** โฟลเดอร์ `quotations/` ในโปรเจกต์ที่คุณเปิดอยู่ใน Claude Code
- ปลั๊กอินอ่านเทมเพลตจาก `${CLAUDE_PLUGIN_ROOT}` จึงทำงานได้ทุกเครื่อง (portable)

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
