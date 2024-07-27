import os
import logging
import sys
import time
import subprocess
import RPi.GPIO as GPIO
from ctypes import *

logger = logging.getLogger(__name__)

class RaspberryPi:
    # Pin definition
    RST_PIN = 17
    DC_PIN = 25
    CS_PIN = 8
    BUSY_PIN = 24
    PWR_PIN = 18
    MOSI_PIN = 10
    SCLK_PIN = 11

    def __init__(self):
        import spidev
        
        self.SPI = spidev.SpiDev()
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        GPIO.setup(self.RST_PIN, GPIO.OUT)
        GPIO.setup(self.DC_PIN, GPIO.OUT)
        GPIO.setup(self.CS_PIN, GPIO.OUT)  # Uncomment this if you are using CS_PIN
        GPIO.setup(self.PWR_PIN, GPIO.OUT)
        GPIO.setup(self.BUSY_PIN, GPIO.IN)

    def digital_write(self, pin, value):
        GPIO.output(pin, value)

    def digital_read(self, pin):
        return GPIO.input(pin)

    def delay_ms(self, delaytime):
        time.sleep(delaytime / 1000.0)

    def spi_writebyte(self, data):
        self.SPI.writebytes(data)

    def spi_writebyte2(self, data):
        self.SPI.writebytes2(data)

    def module_init(self, cleanup=False):
        self.digital_write(self.PWR_PIN, 1)
        
        if cleanup:
            find_dirs = [
                os.path.dirname(os.path.realpath(__file__)),
                '/usr/local/lib',
                '/usr/lib',
            ]
            self.DEV_SPI = None
            for find_dir in find_dirs:
                val = int(os.popen('getconf LONG_BIT').read())
                logging.debug("System is %d bit" % val)
                if val == 64:
                    so_filename = os.path.join(find_dir, 'DEV_Config_64.so')
                else:
                    so_filename = os.path.join(find_dir, 'DEV_Config_32.so')
                if os.path.exists(so_filename):
                    self.DEV_SPI = CDLL(so_filename)
                    break
            if self.DEV_SPI is None:
                raise RuntimeError('Cannot find DEV_Config.so')

            self.DEV_SPI.DEV_Module_Init()

        else:
            # SPI device, bus = 0, device = 0
            self.SPI.open(0, 0)
            self.SPI.max_speed_hz = 4000000
            self.SPI.mode = 0b00
        return 0

    def module_exit(self, cleanup=False):
        logger.debug("spi end")
        self.SPI.close()

        self.digital_write(self.RST_PIN, 0)
        self.digital_write(self.DC_PIN, 0)
        self.digital_write(self.PWR_PIN, 0)
        logger.debug("close 5V, Module enters 0 power consumption ...")
        
        if cleanup:
            GPIO.cleanup([self.RST_PIN, self.DC_PIN, self.PWR_PIN, self.BUSY_PIN])

class JetsonNano:
    # Pin definition
    RST_PIN = 17
    DC_PIN = 25
    CS_PIN = 8
    BUSY_PIN = 24
    PWR_PIN = 18

    def __init__(self):
        import ctypes
        find_dirs = [
            os.path.dirname(os.path.realpath(__file__)),
            '/usr/local/lib',
            '/usr/lib',
        ]
        self.SPI = None
        for find_dir in find_dirs:
            so_filename = os.path.join(find_dir, 'sysfs_software_spi.so')
            if os.path.exists(so_filename):
                self.SPI = ctypes.cdll.LoadLibrary(so_filename)
                break
        if self.SPI is None:
            raise RuntimeError('Cannot find sysfs_software_spi.so')

        import Jetson.GPIO
        self.GPIO = Jetson.GPIO

    def digital_write(self, pin, value):
        self.GPIO.output(pin, value)

    def digital_read(self, pin):
        return self.GPIO.input(self.BUSY_PIN)

    def delay_ms(self, delaytime):
        time.sleep(delaytime / 1000.0)

    def spi_writebyte(self, data):
        self.SPI.SYSFS_software_spi_transfer(data[0])

    def spi_writebyte2(self, data):
        for i in range(len(data)):
            self.SPI.SYSFS_software_spi_transfer(data[i])

    def module_init(self):
        self.GPIO.setmode(self.GPIO.BCM)
        self.GPIO.setwarnings(False)
        self.GPIO.setup(self.RST_PIN, self.GPIO.OUT)
        self.GPIO.setup(self.DC_PIN, self.GPIO.OUT)
        self.GPIO.setup(self.CS_PIN, self.GPIO.OUT)
        self.GPIO.setup(self.PWR_PIN, self.GPIO.OUT)
        self.GPIO.setup(self.BUSY_PIN, self.GPIO.IN)
        
        self.GPIO.output(self.PWR_PIN, 1)
        
        self.SPI.SYSFS_software_spi_begin()
        return 0

    def module_exit(self):
        logger.debug("spi end")
        self.SPI.SYSFS_software_spi_end()

        logger.debug("close 5V, Module enters 0 power consumption ...")
        self.GPIO.output(self.RST_PIN, 0)
        self.GPIO.output(self.DC_PIN, 0)
        self.GPIO.output(self.PWR_PIN, 0)

        self.GPIO.cleanup([self.RST_PIN, self.DC_PIN, self.CS_PIN, self.BUSY_PIN, self.PWR_PIN])


class SunriseX3:
    # Pin definition
    RST_PIN = 17
    DC_PIN = 25
    CS_PIN = 8
    BUSY_PIN = 24
    PWR_PIN = 18
    Flag = 0

    def __init__(self):
        import spidev
        import Hobot.GPIO

        self.GPIO = Hobot.GPIO
        self.SPI = spidev.SpiDev()

    def digital_write(self, pin, value):
        self.GPIO.output(pin, value)

    def digital_read(self, pin):
        return self.GPIO.input(pin)

    def delay_ms(self, delaytime):
        time.sleep(delaytime / 1000.0)

    def spi_writebyte(self, data):
        self.SPI.writebytes(data)

    def spi_writebyte2(self, data):
        self.SPI.xfer3(data)

    def module_init(self):
        if self.Flag == 0:
            self.Flag = 1
            self.GPIO.setmode(self.GPIO.BCM)
            self.GPIO.setwarnings(False)
            self.GPIO.setup(self.RST_PIN, self.GPIO.OUT)
            self.GPIO.setup(self.DC_PIN, self.GPIO.OUT)
            self.GPIO.setup(self.CS_PIN, self.GPIO.OUT)
            self.GPIO.setup(self.PWR_PIN, self.GPIO.OUT)
            self.GPIO.setup(self.BUSY_PIN, self.GPIO.IN)

            self.GPIO.output(self.PWR_PIN, 1)
        
            # SPI device, bus = 0, device = 0
            self.SPI.open(2, 0)
            self.SPI.max_speed_hz = 4000000
            self.SPI.mode = 0b00
            return 0
        else:
            return 0

    def module_exit(self):
        logger.debug("spi end")
        self.SPI.close()

        logger.debug("close 5V, Module enters 0 power consumption ...")
        self.Flag = 0
        self.GPIO.output(self.RST_PIN, 0)
        self.GPIO.output(self.DC_PIN, 0)
        self.GPIO.output(self.PWR_PIN, 0)

        self.GPIO.cleanup([self.RST_PIN, self.DC_PIN, self.CS_PIN, self.BUSY_PIN], self.PWR_PIN)


if sys.version_info[0] == 2:
    process = subprocess.Popen("cat /proc/cpuinfo | grep Raspberry", shell=True, stdout=subprocess.PIPE)
else:
    process = subprocess.Popen("cat /proc/cpuinfo | grep Raspberry", shell=True, stdout=subprocess.PIPE, text=True)
output, _ = process.communicate()
if sys.version_info[0] == 2:
    output = output.decode(sys.stdout.encoding)

if "Raspberry" in output:
    implementation = RaspberryPi()
elif os.path.exists('/sys/bus/platform/drivers/gpio-x3'):
    implementation = SunriseX3()
else:
    implementation = JetsonNano()

for func in [x for x in dir(implementation) if not x.startswith('_')]:
    setattr(sys.modules[__name__], func, getattr(implementation, func))

### END OF FILE ###
