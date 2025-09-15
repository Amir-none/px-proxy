# px-proxy (pxzone)

🇬🇧 **English Description**

Interactive one-line installer for multiple **MTProto proxies** on a single server.  
Features:  
- Custom **ports** (optional)  
- Custom **FakeTLS** domains (optional)  
- Optional **Telegram advertising TAG** (@MTProxybot)  
- **Persistent secrets** (saved per proxy instance)  
- **Auto-restart** with Docker  
- Works on AMD/Intel (x86_64) and ARM64 (with optional `FORCE_PLATFORM`)

> **FakeTLS domains note:**  
> The default FakeTLS list is tuned for **Iran’s network conditions**.  
> If you are outside Iran, you should provide your own domains during setup for better connectivity.


---

🇮🇷 **توضیحات فارسی**

اسکریپت نصب خودکار و تعاملی برای ساخت چندین **پروکسی MTProto** روی یک سرور.  
امکانات:  
- امکان انتخاب **پورت‌ها** (دلخواه یا پیش‌فرض)  
- امکان تعیین **دامنه‌های FakeTLS** (دلخواه یا پیش‌فرض)  
- پشتیبانی از **تگ تبلیغاتی تلگرام** (@MTProxybot)  
- **سکرت‌های پایدار** (برای هر پروکسی جدا ذخیره می‌شوند)  
- **راه‌اندازی خودکار** پس از ریبوت به کمک Docker  
- سازگار با سرورهای **AMD/Intel (x86_64)** و **ARM64** (با امکان `FORCE_PLATFORM`)

> **نکته درباره دامنه‌های FakeTLS:**  
> دامنه‌های پیش‌فرض بر اساس شرایط اینترنت ایران انتخاب شده‌اند.  
> اگر خارج از ایران هستید، بهتر است دامنه‌های مناسب خودتان را موقع نصب وارد کنید.

---

## 🚀 Quick install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Amir-none/px-proxy/main/pxz-mtpmulti-interactive.sh)"
