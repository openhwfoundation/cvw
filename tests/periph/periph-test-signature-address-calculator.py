#!/usr/bin/env -S uv run --script
if __name__ == "__main__":
    import sys
    if (('-h' in sys.argv) or ('--help' in sys.argv)):
        helptxt = "This script helps to develop WALLY-PERIPH.S\n" \
        "Give it a physical address such as 80002084,\n" \
        "and it describes where that address is the signature output."
        print(helptxt)
    else:
        adr = str(input("Address: "))
        try:
            adr = int(adr,16)
        except:
            exit("Oi that was not a valid address.")
        base_adr = int("80002000",16)
        sig_adr = adr-base_adr
        line_num = int(sig_adr / 4) + 1
        offset = sig_adr & 0x3F
        test_num = int((sig_adr-offset)/int("40",16))
        print(f"IntrNum 0x{test_num:02X}")
        print(f"Offset 0x{offset:02X}")
        print("LineNum "+str(line_num))
