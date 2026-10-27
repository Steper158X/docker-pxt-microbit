# pxt-microbit ใน Docker

[English](README.md) | **ภาษาไทย**

รัน MakeCode for micro:bit ([microsoft/pxt-microbit](https://github.com/microsoft/pxt-microbit)) เป็น local server ใน Docker

## เริ่มใช้งาน

```bash
docker compose up -d --build
```

จากนั้นเปิด **http://localhost:3232** บนเครื่องนี้ หรือ **http://&lt;IP เครื่อง host&gt;:3232** (เช่น `http://192.168.1.10:3232`) จากคอมเครื่องอื่นในวงแลนเดียวกัน

- การ build ครั้งแรกใช้เวลาหลายนาที (clone, `npm install`, `pxt buildtarget`, `pxt staticpkg` พร้อมสร้าง hex cache)
- ค่าเริ่มต้น container จะเสิร์ฟ editor เป็นเว็บ static (โหมด `static`) ไม่ต้องใช้ token เปิดจากเครื่องไหนในวงแลนก็ได้ และปุ่ม **Download** ใช้ hex cache ที่ฝังมา จึงใช้งาน offline ได้
- โปรเจกต์จะบันทึกไว้ในเบราว์เซอร์ของแต่ละเครื่อง ถ้าต้องการเก็บสำรองให้กด **Download** หรือ **Export**
- ดู IP ของเครื่อง host บน Windows ด้วยคำสั่ง `ipconfig` ถ้าเครื่องอื่นเข้าไม่ได้ ให้เปิดพอร์ต 3232 ใน firewall ของเครื่อง host

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
- โปรเจกต์ที่ import มาและอ้างถึง extension แบบ `github:...` จะยังพยายามโหลดจาก GitHub ให้ลบ extension นั้นออกแล้วเพิ่มตัวที่ฝังไว้จากหน้า Extensions แทน

## WebUSB (HTTPS)

เบราว์เซอร์อนุญาต WebUSB เฉพาะ `https://` หรือ `localhost` เพื่อให้เครื่องอื่น flash micro:bit จากเบราว์เซอร์ได้โดยตรง container จะเสิร์ฟ HTTPS เพิ่มที่พอร์ต 3443 ด้วย cert ที่สร้างขึ้นเอง

1. ใส่ IP ของเครื่อง host ใน `docker-compose.yml` (ใส่ชื่อเครื่องเพิ่มได้ คั่นด้วยจุลภาค) แล้วเปิด container

   ```yaml
   environment:
     PXT_TLS_HOSTS: "192.168.1.10"
   ```

   ```bash
   docker compose up -d
   ```

2. บนเครื่องลูกข่ายแต่ละเครื่อง ติดตั้ง CA ครั้งเดียว: เปิด **http://&lt;IP เครื่อง host&gt;:3232/rootCA.crt** เปิดไฟล์ที่ดาวน์โหลดมา กด **Install Certificate** แล้วเลือกเก็บใน "Trusted Root Certification Authorities" หรือใช้คำสั่ง (ไม่ต้องเป็น admin)

   ```bash
   certutil -user -addstore Root rootCA.crt
   ```

3. เปิด **https://&lt;IP เครื่อง host&gt;:3443** ใน Chrome หรือ Edge เสียบ micro:bit กด **Connect device** จากนั้นกด **Download** จะ flash ลงบอร์ดโดยตรง ถ้าไม่เจอบอร์ดให้อัปเดต firmware DAPLink

การทำงาน
- ตอนเริ่มครั้งแรก container จะสร้าง CA ของตัวเองเก็บไว้ใน volume `pxt-tls` แล้วออก cert ของ server ให้ `localhost` และ host ใน `PXT_TLS_HOSTS` และจะออกใบใหม่เองเมื่อ host เปลี่ยนหรือใกล้หมดอายุ
- CA นี้ออก cert ได้เฉพาะ IP ภายใน (`10.x`, `172.16-31.x`, `192.168.x`, `127.x`) และชื่อที่ลงท้ายด้วย `.local`, `.lan`, `.home.arpa` หรือ `.internal` ต่อให้ key หลุดก็ปลอมเป็นเว็บไซต์สาธารณะไม่ได้ host อื่นใน `PXT_TLS_HOSTS` จะถูกข้ามพร้อมคำเตือน
- เสิร์ฟเฉพาะ cert สาธารณะของ CA ค่า fingerprint SHA-256 แสดงใน `docker compose logs` ใช้เทียบกับตอนติดตั้งได้
- เปลี่ยน IP ใน `PXT_TLS_HOSTS` ไม่ต้องติดตั้ง CA ใหม่ แต่ถ้าลบ volume (`docker compose down -v`) จะได้ CA ใหม่ และทุกเครื่องต้องติดตั้งใหม่
- ควรจอง IP ของเครื่อง host ไว้ที่ router (DHCP reservation) เพื่อไม่ให้ IP เปลี่ยน
- เปิดพอร์ต 3443 ใน firewall ของเครื่อง host ด้วย
- ถ้าต้องการใช้ cert ของตัวเอง (เช่นจาก mkcert) ให้ mount โฟลเดอร์ที่มี `cert.pem` และ `key.pem` ไปที่ `/certs` เช่นเพิ่ม `- ./certs:/certs:ro` ใน `volumes`

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
| `static` (ค่าเริ่มต้น) | เสิร์ฟ editor แบบ packaged (`built/packaged`) ให้ทุกเครื่องในวงแลน |
| `serve` | `pxt serve --just` เป็น dev server ของ pxt บันทึกโปรเจกต์ลง volume `pxt-projects` (`/app/projects`) hex cache ใช้ได้เฉพาะเมื่อเปิดผ่าน `localhost`, `127.0.0.1`, `192.168.x.x` หรือ `*.local` และเปิดด้วย `#local_token=offline` อย่างน้อยหนึ่งครั้ง |
| `serve-full` | เหมือน `serve` แต่ build target ใหม่ก่อน |
| คำสั่งอื่น | รันตรง ๆ เช่น `docker compose run --rm pxt-microbit pxt help` |

ถ้าจะใช้โหมด `serve` ให้เพิ่ม `command: serve` ใน service ของ `docker-compose.yml`

ตัวแปรสภาพแวดล้อม: `PXT_PORT` (ค่าเริ่มต้น 3232), `PXT_HTTPS_PORT` (3443 ใช้เฉพาะ `static`), `PXT_TLS_HOSTS` (ว่าง: IP/ชื่อของ host สำหรับ cert HTTPS), `PXT_WSPORT` (3233 ใช้เฉพาะ `serve`), `PXT_LOCAL_TOKEN` (`offline` ใช้เฉพาะ `serve`)

## หมายเหตุ

- server ไม่มีระบบยืนยันตัวตน ให้ใช้เฉพาะในวงแลน ห้ามเปิดพอร์ตนี้สู่อินเทอร์เน็ต
- การคอมไพล์ C++ (`.cpp`) ที่ไม่มีใน hex cache ใช้ cloud build ของ MakeCode จึงต้องมีอินเทอร์เน็ต
- การ flash ผ่าน WebUSB ทำจากเบราว์เซอร์ฝั่งเครื่องคุณ (Chrome/Edge) ไม่ต้องส่ง USB เข้า container
- เครื่องอื่นที่เปิดผ่าน `http://<IP เครื่อง host>:3232` เมื่อกด **Download** จะได้ไฟล์ `.hex` ให้ลากไฟล์ไปวางในไดรฟ์ `MICROBIT` ถ้าต้องการ WebUSB ให้ใช้ที่อยู่ HTTPS (ดูหัวข้อด้านบน)
