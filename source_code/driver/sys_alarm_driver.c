/*
 * sys_alarm_driver.c — System Alarm Platform Sürücüsü
 *
 * Device Tree Bağlayıcısı : "marmara,system-alarm"
 * Karakter Aygıtı         : /dev/sys_alarm  (misc, major=10)
 *
 * Donanım Adresi : 0x09080000 (QEMU virt MMIO alanı)
 * Hedef Çekirdek : Linux 6.1.75, ARM64
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

#define DRIVER_NAME    "sys_alarm"
#define DRIVER_DESC    "System Alarm Platform Surucusu — marmara,system-alarm"
#define DRIVER_VERSION "1.0"
#define REG_ALARM_CTRL   0x00

#define QEMU_SIMULATION  1

struct sys_alarm_priv {
    void __iomem    *base;
    struct miscdevice misc;
    u8               state;
};

static struct sys_alarm_priv *g_priv;

static int sys_alarm_open(struct inode *inode, struct file *filp)
{
    filp->private_data = g_priv;
    pr_info("[%s] /dev/sys_alarm acildi\n", DRIVER_NAME);
    return 0;
}

static int sys_alarm_release(struct inode *inode, struct file *filp)
{
    pr_info("[%s] /dev/sys_alarm kapatildi\n", DRIVER_NAME);
    return 0;
}

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
        if (priv->base)
            iowrite32(0x1, priv->base + REG_ALARM_CTRL);
#endif
        /* Kalın Kırmızı Çıktı */
        pr_warn("\033[1;31m[DONANIM] Kirmizi Alarm Aktif!\033[0m\n");

    } else if (kbuf[0] == '0') {
        priv->state = 0;

#if !QEMU_SIMULATION
        if (priv->base)
            iowrite32(0x0, priv->base + REG_ALARM_CTRL);
#endif
        /* Kalın Yeşil Çıktı */
        pr_info("\033[1;32m[DONANIM] Alarm Devre Disi.\033[0m\n");

    } else {
        pr_debug("[%s] Bilinmeyen komut: 0x%02x\n", DRIVER_NAME, kbuf[0]);
    }

    return (ssize_t)count;
}

static const struct file_operations sys_alarm_fops = {
    .owner   = THIS_MODULE,
    .open    = sys_alarm_open,
    .release = sys_alarm_release,
    .write   = sys_alarm_write,
};

static int sys_alarm_probe(struct platform_device *pdev)
{
    struct sys_alarm_priv *priv;
    struct resource *res;
    int ret;

    dev_info(&pdev->dev, "probe() cagrildi — DT dugumu eslesti\n");

    priv = devm_kzalloc(&pdev->dev, sizeof(*priv), GFP_KERNEL);
    if (!priv)
        return -ENOMEM;

    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    if (!res) {
        dev_err(&pdev->dev, "DT 'reg' ozelligi okunamadi\n");
        return -ENODEV;
    }

#if QEMU_SIMULATION
    priv->base = NULL;
    dev_info(&pdev->dev,
             "QEMU modu: MMIO 0x%08llx ioremap ATLIYOR (External Abort onleme)\n",
             (unsigned long long)res->start);
#else
    {
        void __iomem *base = devm_ioremap_resource(&pdev->dev, res);
        if (IS_ERR(base)) {
            dev_err(&pdev->dev, "ioremap() basarisiz: %ld\n", PTR_ERR(base));
            return PTR_ERR(base);
        }
        priv->base = base;
    }
#endif
    priv->state = 0;

    priv->misc.minor = MISC_DYNAMIC_MINOR;
    priv->misc.name  = "sys_alarm";
    priv->misc.fops  = &sys_alarm_fops;
    priv->misc.mode  = 0666;

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

static int sys_alarm_remove(struct platform_device *pdev)
{
    struct sys_alarm_priv *priv = platform_get_drvdata(pdev);

    misc_deregister(&priv->misc);
    g_priv = NULL;

    dev_info(&pdev->dev, "/dev/sys_alarm kaldirildi\n");
    return 0;
}

static const struct of_device_id sys_alarm_of_match[] = {
    { .compatible = "marmara,system-alarm" },
    { }
};
MODULE_DEVICE_TABLE(of, sys_alarm_of_match);

static struct platform_driver sys_alarm_platform_driver = {
    .probe  = sys_alarm_probe,
    .remove = sys_alarm_remove,
    .driver = {
        .name           = DRIVER_NAME,
        .of_match_table = sys_alarm_of_match,
        .owner          = THIS_MODULE,
    },
};

module_platform_driver(sys_alarm_platform_driver);

MODULE_LICENSE("GPL v2");
MODULE_AUTHOR("Marmara Embedded Systems");
MODULE_DESCRIPTION(DRIVER_DESC);
MODULE_VERSION(DRIVER_VERSION);