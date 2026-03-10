; Minimal descriptors for MK61 FX2 bridge firmware

.module DEV_DSCR

DSCR_DEVICE_TYPE=1
DSCR_CONFIG_TYPE=2
DSCR_STRING_TYPE=3
DSCR_INTERFACE_TYPE=4
DSCR_DEVQUAL_TYPE=6

.globl _dev_dscr, _dev_qual_dscr, _highspd_dscr, _fullspd_dscr, _dev_strings, _dev_strings_end

.area DSCR_AREA (CODE)

_dev_dscr:
    .db 18                      ; bLength
    .db DSCR_DEVICE_TYPE        ; bDescriptorType
    .dw 0x0200                  ; bcdUSB
    .db 0xFF                    ; bDeviceClass (vendor)
    .db 0x00                    ; bDeviceSubClass
    .db 0x00                    ; bDeviceProtocol
    .db 64                      ; bMaxPacketSize0
    .dw 0x04B4                  ; idVendor (Cypress)
    .dw 0x1004                  ; idProduct (custom runtime)
    .dw 0x0001                  ; bcdDevice
    .db 1                       ; iManufacturer
    .db 2                       ; iProduct
    .db 0                       ; iSerialNumber
    .db 1                       ; bNumConfigurations

_dev_qual_dscr:
    .db 10                      ; bLength
    .db DSCR_DEVQUAL_TYPE       ; bDescriptorType
    .dw 0x0200                  ; bcdUSB
    .db 0xFF                    ; bDeviceClass
    .db 0x00                    ; bDeviceSubClass
    .db 0x00                    ; bDeviceProtocol
    .db 64                      ; bMaxPacketSize0
    .db 1                       ; bNumConfigurations
    .db 0                       ; reserved

_highspd_dscr:
    .db 9                       ; bLength
    .db DSCR_CONFIG_TYPE        ; bDescriptorType
    .db (highspd_dscr_realend-_highspd_dscr) % 256
    .db (highspd_dscr_realend-_highspd_dscr) / 256
    .db 1                       ; bNumInterfaces
    .db 1                       ; bConfigurationValue
    .db 0                       ; iConfiguration
    .db 0x80                    ; bmAttributes (bus-powered)
    .db 0x32                    ; bMaxPower (100mA)

    ; Interface 0, alternate 0, no extra endpoints (EP0 only)
    .db 9                       ; bLength
    .db DSCR_INTERFACE_TYPE     ; bDescriptorType
    .db 0                       ; bInterfaceNumber
    .db 0                       ; bAlternateSetting
    .db 0                       ; bNumEndpoints
    .db 0xFF                    ; bInterfaceClass
    .db 0x00                    ; bInterfaceSubClass
    .db 0x00                    ; bInterfaceProtocol
    .db 0                       ; iInterface

highspd_dscr_realend:

_fullspd_dscr:
    .db 9                       ; bLength
    .db DSCR_CONFIG_TYPE        ; bDescriptorType
    .db (fullspd_dscr_realend-_fullspd_dscr) % 256
    .db (fullspd_dscr_realend-_fullspd_dscr) / 256
    .db 1                       ; bNumInterfaces
    .db 1                       ; bConfigurationValue
    .db 0                       ; iConfiguration
    .db 0x80                    ; bmAttributes (bus-powered)
    .db 0x32                    ; bMaxPower (100mA)

    ; Interface 0, alternate 0, no extra endpoints (EP0 only)
    .db 9                       ; bLength
    .db DSCR_INTERFACE_TYPE     ; bDescriptorType
    .db 0                       ; bInterfaceNumber
    .db 0                       ; bAlternateSetting
    .db 0                       ; bNumEndpoints
    .db 0xFF                    ; bInterfaceClass
    .db 0x00                    ; bInterfaceSubClass
    .db 0x00                    ; bInterfaceProtocol
    .db 0                       ; iInterface

fullspd_dscr_realend:

_dev_strings:
_string0:
    .db 4                       ; bLength
    .db DSCR_STRING_TYPE        ; bDescriptorType
    .db 0x09, 0x04              ; LANGID English (US)

_string1:
    .db 10                      ; bLength
    .db DSCR_STRING_TYPE
    .db 'M',0,'K',0,'6',0,'1',0

_string2:
    .db 32                      ; bLength
    .db DSCR_STRING_TYPE
    .db 'M',0,'K',0,'6',0,'1',0,' ',0,'F',0,'X',0,'2',0,' ',0,'B',0,'r',0,'i',0,'d',0,'g',0,'e',0

_dev_strings_end:
    .dw 0x0000
