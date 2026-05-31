/*
 * sys_alarm_driver.c — System Alarm Platform Sürücüsü
 *
 * Device Tree Bağlayıcısı : "marmara,system-alarm"
 * Karakter Aygıtı         : /dev/sys_alarm  (misc, major=10)
 *
 * Donanım Adresi : 0x09080000 (QEMU virt MMIO alanı)
 * Hedef Çekirdek : Linux 6.1.75, ARM64
 *
 * NOT: QEMU simülasyonunda 0x09080000 adresinde fiziksel donanım
 *      bulunmadığından iowrite32() KULLANILMAZ. Alarm durumu yazılım
 *      değişkeni (state) ve dmesg mesajları üzerinden yönetilir.
 *      Gerçek donanımda bu blokların yorumu açılır.
 *
 * Kullanım (QEMU içinde):
 *   insmod /lib/modules/sys_alarm_driver.ko
 *   echo 1 > /dev/sys_alarm   -> [DONANIM] Kırmızı Alarm Aktif!
 *   echo 0 > /dev/sys_alarm   -> [DONANIM] Alarm Devre Disi.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/io.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/miscdevice.h>
#include <linux/slab.h>

/* ─── Modül meta verileri ───────────────────────────────────── */
#define DRIVER_NAME    "sys_alarm"
#define DRIVER_DESC    "System Alarm Platform Surucusu — marmara,system-alarm"
#define DRIVER_VERSION "1.0"

/* MMIO yazmaç ofseti (referans — QEMU simülasyonunda kullanılmaz) */
#define REG_ALARM_CTRL   0x00   /* 0x1 = aktif, 0x0 = pasif */

/*
 * QEMU_SIMULATION: 1 olduğunda iowrite32() çağrıları devre dışı bırakılır.
 * Gerçek donanım hedefinde 0 yapın.
 */
#define QEMU_SIMULATION  1

/* ─── Sürücü durum yapısı ───────────────────────────────────── */
struct sys_alarm_priv {
    void __iomem    *base;      /* MMIO sanal adres tabanı      */
    struct miscdevice misc;     /* Karakter aygıt tanıtıcısı    */
    u8               state;     /* Mevcut alarm durumu (0/1)    */
};

/* Probe sonrası global erişim için (write() içinde kullanılır) */
static struct sys_alarm_priv *g_priv;

/* ─── file_operations: open ─────────────────────────────────── */
static int sys_alarm_open(struct inode *inode, struct file *filp)
{
    filp->private_data = g_priv;
    pr_info("[%s] /dev/sys_alarm acildi\n", DRIVER_NAME);
    return 0;
}

/* ─── file_operations: release ─────────────────────────────── */
static int sys_alarm_release(struct inode *inode, struct file *filp)
{
    pr_info("[%s] /dev/sys_alarm kapatildi\n", DRIVER_NAME);
    return 0;
}

/* ─── file_operations: write ────────────────────────────────── */
/*
 * '1' yazılırsa → alarm aktif  → MMIO 0x1 yaz → dmesg uyarı
 * '0' yazılırsa → alarm pasif  → MMIO 0x0 yaz → dmesg bilgi
 * Diğer değerler → görmezden gel
 */
static ssize_t sys_alarm_write(struct file *filp,
                               const char __user *buf,
                               size_t count,
                               loff_t *ppos)
{
    struct sys_alarm_priv *priv = filp->private_data;
    char kbuf[4] = {0};
    size_t copy_len;

    if (!count)
        return 0;

    copy_len = min(count, sizeof(kbuf) - 1);
    if (copy_from_user(kbuf, buf, copy_len))
        return -EFAULT;

    if (kbuf[0] == '1') {
        priv->state = 1;

#if !QEMU_SIMULATION
        /* Gerçek donanımda bu blok aktif edilir.
         * QEMU'da 0x09080000'e yazılması Synchronous External Abort üretir!
         * Neden: QEMU virt makinesinde bu adrese map edilmiş donanım yok.
         */
        if (priv->base)
            iowrite32(0x1, priv->base + REG_ALARM_CTRL);
#endif

        pr_warn("[DONANIM] Kirmizi Alarm Aktif!\n");

    } else if (kbuf[0] == '0') {
        priv->state = 0;

#if !QEMU_SIMULATION
        if (priv->base)
            iowrite32(0x0, priv->base + REG_ALARM_CTRL);
#endif

        pr_info("[DONANIM] Alarm Devre Disi.\n");

    } else {
        pr_debug("[%s] Bilinmeyen komut: 0x%02x\n", DRIVER_NAME, kbuf[0]);
    }

    return (ssize_t)count;   /* Tüm baytlar işlendi */
}

/* ─── file_operations tablosu ───────────────────────────────── */
static const struct file_operations sys_alarm_fops = {
    .owner   = THIS_MODULE,
    .open    = sys_alarm_open,
    .release = sys_alarm_release,
    .write   = sys_alarm_write,
};

/* ─── Platform sürücüsü: probe() ───────────────────────────── */
static int sys_alarm_probe(struct platform_device *pdev)
{
    struct sys_alarm_priv *priv;
    struct resource *res;
    int ret;
#if !QEMU_SIMULATION
    void __iomem *base;
#endif

    dev_info(&pdev->dev, "probe() cagrildi — DT dugumu eslesti\n");

    /* ── 1. Sürücü durum belleği ── */
    priv = devm_kzalloc(&pdev->dev, sizeof(*priv), GFP_KERNEL);
    if (!priv)
        return -ENOMEM;

    /* ── 2. MMIO kaynak okuma (DT binding gösterimi için) ──
     * QEMU simülasyonunda fiilen ioremap yapilmaz — yazmak External Abort uretir.
     * res->start degerini sadece loglama amacli okuyoruz.
     */
    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    if (!res) {
        dev_err(&pdev->dev, "DT 'reg' ozelligi okunamadi\n");
        return -ENODEV;
    }

#if QEMU_SIMULATION
    /* QEMU: ioremap atlanir, base = NULL, iowrite32 hic cagrilmaz */
    priv->base = NULL;
    dev_info(&pdev->dev,
             "QEMU modu: MMIO 0x%08llx ioremap ATLIYOR (External Abort onleme)\n",
             (unsigned long long)res->start);
#else
    /* Gercek donanim: ioremap yap */
    base = devm_ioremap_resource(&pdev->dev, res);
    if (IS_ERR(base)) {
        dev_err(&pdev->dev, "ioremap() basarisiz: %ld\n", PTR_ERR(base));
        return PTR_ERR(base);
    }
    priv->base = base;
#endif
    priv->state = 0;

    /* ── 3. Karakter aygıt kaydı (misc) ── */
    priv->misc.minor = MISC_DYNAMIC_MINOR;
    priv->misc.name  = "sys_alarm";
    priv->misc.fops  = &sys_alarm_fops;
    priv->misc.mode  = 0666;   /* Kullanıcı uzayından yazılabilir */

    ret = misc_register(&priv->misc);
    if (ret) {
        dev_err(&pdev->dev, "misc_register basarisiz: %d\n", ret);
        return ret;
    }

    g_priv = priv;
    platform_set_drvdata(pdev, priv);

    dev_info(&pdev->dev,
             "/dev/sys_alarm olusturuldu (major=10, minor=%d)\n"
             "  MMIO baz adresi : 0x%08llx\n"
             "  Eslesen dugum   : %s\n",
             priv->misc.minor,
             (unsigned long long)res->start,
             pdev->name);

    return 0;
}

/* ─── Platform sürücüsü: remove() ──────────────────────────── */
static int sys_alarm_remove(struct platform_device *pdev)
{
    struct sys_alarm_priv *priv = platform_get_drvdata(pdev);

    misc_deregister(&priv->misc);
    g_priv = NULL;

    dev_info(&pdev->dev, "/dev/sys_alarm kaldirildi\n");
    return 0;
}

/* ─── Device Tree eşleşme tablosu ───────────────────────────── */
static const struct of_device_id sys_alarm_of_match[] = {
    {
        .compatible = "marmara,system-alarm",
    },
    { /* sentinel — liste sonu */ }
};
MODULE_DEVICE_TABLE(of, sys_alarm_of_match);

/* ─── Platform sürücü yapısı ────────────────────────────────── */
static struct platform_driver sys_alarm_platform_driver = {
    .probe  = sys_alarm_probe,
    .remove = sys_alarm_remove,
    .driver = {
        .name           = DRIVER_NAME,
        .of_match_table = sys_alarm_of_match,
        .owner          = THIS_MODULE,
    },
};

/* module_platform_driver() → init/exit otomatik oluşturur */
module_platform_driver(sys_alarm_platform_driver);

MODULE_LICENSE("GPL v2");
MODULE_AUTHOR("Marmara Embedded Systems");
MODULE_DESCRIPTION(DRIVER_DESC);
MODULE_VERSION(DRIVER_VERSION);
