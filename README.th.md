# pxt-microbit ใน Docker

[English](README.md) | **ภาษาไทย**

รัน MakeCode for micro:bit ([microsoft/pxt-microbit](https://github.com/microsoft/pxt-microbit)) เป็น local server ใน Docker

## เริ่มใช้งาน

```bash
docker compose up -d --build
```

จากนั้นเปิด **http://localhost:3232/#local_token=offline** (ครั้งแรกครั้งเดียว เบราว์เซอร์จะจำ token ไว้ ครั้งต่อไปเปิด http://localhost:3232 ได้เลย)

- การ build ครั้งแรกใช้เวลาหลายนาที (clone, `npm install`, `pxt buildtarget`, สร้าง hex cache)
- ต้องเปิดด้วย token ก่อน ไม่อย่างนั้นเว็บจะไม่ใช้ local server คือไม่ใช้ hex cache แบบ offline และไม่บันทึกโปรเจกต์ลงเซิร์ฟเวอร์
- โปรเจกต์ที่บันทึกบน local server จะเก็บไว้ใน volume `pxt-projects` (`/app/projects`)

## Extension แบบ offline

ใส่ชื่อ repo GitHub ของ extension ลงใน [extensions.txt](extensions.txt) บรรทัดละหนึ่งตัว แล้ว build ใหม่

```
microsoft/pxt-neopixel
microbit-foundation/pxt-microbit-v2-power
owner/repo#v1.2.3
```

```bash
docker compose up -d --build
```

ตอน build ระบบจะ
1. clone extension ทุกตัว รวมถึง extension ที่ตัวมันพึ่งพาด้วย (เช่น neopixel พึ่ง ws2812b) แล้วเก็บไว้ใน `libs/`
2. ลงทะเบียน extension เหล่านี้เป็นแบบ bundled จึงขึ้นในหน้า **Extensions** ของ editor และใช้ได้โดยไม่ต้องต่อ GitHub
3. คอมไพล์ C++ ล่วงหน้าผ่าน cloud build ไว้ที่ `built/hexcache` สำหรับโปรเจกต์พื้นฐานที่เพิ่ม extension หนึ่งตัว

ข้อจำกัด
- ตอน build image ต้องมีอินเทอร์เน็ต แต่หลังจากนั้นใช้ offline ได้
- extension ที่เป็น TypeScript ล้วนใช้ได้กับทุกแบบผสม ส่วน extension ที่มี C++ จะมี hex เตรียมไว้เฉพาะกรณีเพิ่ม **หนึ่งตัว** ต่อโปรเจกต์ ถ้าใช้ extension ที่มี C++ สองตัวขึ้นไปพร้อมกัน ยังต้องคอมไพล์ผ่าน cloud
- hex cache ใช้ได้เมื่อเปิดผ่าน `localhost` และมี token
- โปรเจกต์ที่ import มาและอ้างถึง extension แบบ `github:...` จะยังพยายามโหลดจาก GitHub ให้ลบ extension นั้นออกแล้วเพิ่มตัวที่ฝังไว้จากหน้า Extensions แทน
- ถ้าไม่ต้องการ hex cache (build เร็วขึ้น) ให้ตั้ง build arg `PXT_OFFLINE_HEX=0`

## คำสั่งที่ใช้บ่อย

```bash
docker compose logs -f          # ดู log
docker compose down             # หยุด
docker compose build --no-cache # ดึงโค้ดล่าสุดแล้ว build ใหม่
```

เลือกเวอร์ชันได้โดยแก้ `PXT_MICROBIT_REF` ใน `docker-compose.yml` (branch หรือ tag เช่น `v9.1.1`)

## โหมดของ entrypoint

| คำสั่ง | ความหมาย |
|---|---|
| `serve` (ค่าเริ่มต้น) | `pxt serve --just` ใช้ target ที่ build ไว้ใน image เริ่มเร็ว |
| `serve-full` | build target ใหม่ก่อน serve |
| คำสั่งอื่น | รันตรง ๆ เช่น `docker compose run --rm pxt-microbit pxt help` |

ตัวแปรสภาพแวดล้อม: `PXT_PORT` (ค่าเริ่มต้น 3232), `PXT_WSPORT` (3233), `PXT_LOCAL_TOKEN` (`offline`)

## หมายเหตุ

- server เปิดด้วย `--noauth` ห้ามเปิดพอร์ตนี้สู่อินเทอร์เน็ต
- การคอมไพล์ C++ (`.cpp`) ที่ไม่มีใน hex cache ใช้ cloud build ของ MakeCode จึงต้องมีอินเทอร์เน็ต
- การ flash ผ่าน WebUSB ทำจากเบราว์เซอร์ฝั่งเครื่องคุณ (Chrome/Edge) ไม่ต้องส่ง USB เข้า container
